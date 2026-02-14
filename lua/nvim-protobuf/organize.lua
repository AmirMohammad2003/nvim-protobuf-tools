-- Import organization for nvim-protobuf
-- Groups and sorts imports according to configuration
local M = {}

-- Parse imports from buffer
local function parse_imports(lines)
  local imports = {}
  local import_lines = {}

  for i, line in ipairs(lines) do
    local import_path = line:match('^%s*import%s+"([^"]+)"%s*;')

    if import_path then
      table.insert(imports, {
        path = import_path,
        line_num = i,
        original_line = line,
      })
      table.insert(import_lines, i)
    end
  end

  return imports, import_lines
end

-- Categorize imports
local function categorize_imports(imports)
  local categories = {
    google = {},
    third_party = {},
    local_imports = {},
  }

  for _, import in ipairs(imports) do
    if import.path:match('^google/') then
      table.insert(categories.google, import)
    elseif import.path:match('^%.') or import.path:match('^/') then
      table.insert(categories.local_imports, import)
    else
      table.insert(categories.third_party, import)
    end
  end

  return categories
end

-- Sort imports alphabetically within each category
local function sort_imports(imports)
  table.sort(imports, function(a, b)
    return a.path < b.path
  end)
  return imports
end

-- Generate organized import lines
local function generate_import_lines(categories, group_by_category)
  local lines = {}

  if group_by_category then
    -- Google imports
    if #categories.google > 0 then
      for _, import in ipairs(sort_imports(categories.google)) do
        table.insert(lines, string.format('import "%s";', import.path))
      end
      table.insert(lines, '')
    end

    -- Third-party imports
    if #categories.third_party > 0 then
      for _, import in ipairs(sort_imports(categories.third_party)) do
        table.insert(lines, string.format('import "%s";', import.path))
      end
      table.insert(lines, '')
    end

    -- Local imports
    if #categories.local_imports > 0 then
      for _, import in ipairs(sort_imports(categories.local_imports)) do
        table.insert(lines, string.format('import "%s";', import.path))
      end
    end

    -- Remove trailing empty line
    if #lines > 0 and lines[#lines] == '' then
      table.remove(lines)
    end
  else
    -- Just sort all imports together
    local all_imports = {}
    vim.list_extend(all_imports, categories.google)
    vim.list_extend(all_imports, categories.third_party)
    vim.list_extend(all_imports, categories.local_imports)

    for _, import in ipairs(sort_imports(all_imports)) do
      table.insert(lines, string.format('import "%s";', import.path))
    end
  end

  return lines
end

-- Organize imports in current buffer
function M.organize()
  local config = require('nvim-protobuf.config').get()
  local organize_config = config.organizeImports or {}

  if not organize_config.enabled then
    require('nvim-protobuf.utils').notify('Import organization is disabled', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Parse imports
  local imports, import_lines = parse_imports(lines)

  if #imports == 0 then
    require('nvim-protobuf.utils').notify('No imports found', vim.log.levels.INFO)
    return
  end

  -- Categorize and organize
  local categories = categorize_imports(imports)
  local organized = generate_import_lines(categories, organize_config.groupByCategory ~= false)

  -- Find the import block range
  local first_import = import_lines[1]
  local last_import = import_lines[#import_lines]

  -- Remove old imports
  vim.api.nvim_buf_set_lines(bufnr, first_import - 1, last_import, false, organized)

  require('nvim-protobuf.utils').notify('Imports organized', vim.log.levels.INFO)
end

return M
