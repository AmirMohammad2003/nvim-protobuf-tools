-- Schema dependency graph visualization for nvim-protobuf
local M = {}

-- Parse imports from a proto file
local function parse_imports(file_path)
  local imports = {}

  if vim.fn.filereadable(file_path) ~= 1 then
    return imports
  end

  local content = table.concat(vim.fn.readfile(file_path), '\n')

  for import_path in content:gmatch('import%s+"([^"]+)"') do
    table.insert(imports, import_path)
  end

  return imports
end

-- Resolve import path to absolute path
local function resolve_import(import_path)
  local config = require('nvim-protobuf.config').get()

  -- Try each include path
  for _, include_path in ipairs(config.includes) do
    local full_path = include_path .. '/' .. import_path

    if vim.fn.filereadable(full_path) == 1 then
      return full_path
    end
  end

  -- Try relative to workspace root
  local utils = require('nvim-protobuf.utils')
  local workspace_root = utils.find_workspace_root()
  local full_path = workspace_root .. '/' .. import_path

  if vim.fn.filereadable(full_path) == 1 then
    return full_path
  end

  return nil
end

-- Build dependency tree recursively
local function build_dependency_tree(file_path, visited)
  visited = visited or {}

  -- Check for circular dependency
  if visited[file_path] then
    return { name = file_path, circular = true }
  end

  visited[file_path] = true

  local tree = {
    name = file_path,
    children = {},
  }

  local imports = parse_imports(file_path)

  for _, import in ipairs(imports) do
    local resolved = resolve_import(import)

    if resolved then
      local child_tree = build_dependency_tree(resolved, vim.deepcopy(visited))
      table.insert(tree.children, child_tree)
    else
      -- Show unresolved import
      table.insert(tree.children, {
        name = import,
        unresolved = true,
      })
    end
  end

  return tree
end

-- Convert tree to display lines
local function tree_to_lines(tree, indent)
  indent = indent or 0
  local lines = {}
  local prefix = string.rep('  ', indent)

  local name = vim.fn.fnamemodify(tree.name, ':t')

  if tree.circular then
    table.insert(lines, prefix .. '○ ' .. name .. ' (circular)')
  elseif tree.unresolved then
    table.insert(lines, prefix .. '✗ ' .. name .. ' (unresolved)')
  else
    table.insert(lines, prefix .. '• ' .. name)
  end

  for _, child in ipairs(tree.children or {}) do
    local child_lines = tree_to_lines(child, indent + 1)
    vim.list_extend(lines, child_lines)
  end

  return lines
end

-- Display tree in floating window
local function display_tree(tree)
  local lines = tree_to_lines(tree, 0)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'proto-graph'
  vim.bo[buf].modifiable = false

  -- Calculate window size
  local width = 80
  local max_line_length = 0
  for _, line in ipairs(lines) do
    max_line_length = math.max(max_line_length, #line)
  end
  width = math.min(math.max(max_line_length + 4, 40), vim.o.columns - 4)

  local height = math.min(#lines + 2, vim.o.lines - 4)

  -- Create floating window
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Proto Dependency Graph ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set up key mappings to close window
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
end

-- Show schema dependency graph for current file
function M.show()
  local file_path = vim.api.nvim_buf_get_name(0)

  if file_path == '' then
    require('nvim-protobuf.utils').notify('No file to analyze', vim.log.levels.ERROR)
    return
  end

  local utils = require('nvim-protobuf.utils')

  if not utils.is_proto_file(file_path) then
    utils.notify('Not a proto file', vim.log.levels.ERROR)
    return
  end

  -- Build dependency tree
  local tree = build_dependency_tree(file_path)

  -- Display tree
  display_tree(tree)
end

return M
