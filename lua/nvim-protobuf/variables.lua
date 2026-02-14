-- Variable substitution engine for nvim-protobuf
-- Supports VSCode-style variables like ${workspaceFolder}, ${file}, ${env:VAR}, etc.
local M = {}

-- Get workspace folder
local function get_workspace_folder()
  return require('nvim-protobuf.utils').find_workspace_root()
end

-- Get current file path
local function get_file()
  return vim.api.nvim_buf_get_name(0)
end

-- Get directory of current file
local function get_file_dirname()
  local file = get_file()
  if file == '' then
    return vim.fn.getcwd()
  end
  return vim.fn.fnamemodify(file, ':h')
end

-- Get base name of current file (with extension)
local function get_file_basename()
  local file = get_file()
  if file == '' then
    return ''
  end
  return vim.fn.fnamemodify(file, ':t')
end

-- Get base name of current file (without extension)
local function get_file_basename_noext()
  local file = get_file()
  if file == '' then
    return ''
  end
  return vim.fn.fnamemodify(file, ':t:r')
end

-- Get file extension
local function get_file_extname()
  local file = get_file()
  if file == '' then
    return ''
  end
  return vim.fn.fnamemodify(file, ':e')
end

-- Variable resolver functions
local resolvers = {
  ['${workspaceFolder}'] = get_workspace_folder,
  ['${workspaceFolderBasename}'] = function()
    return vim.fn.fnamemodify(get_workspace_folder(), ':t')
  end,
  ['${file}'] = get_file,
  ['${fileDirname}'] = get_file_dirname,
  ['${fileBasename}'] = get_file_basename,
  ['${fileBasenameNoExtension}'] = get_file_basename_noext,
  ['${fileExtname}'] = get_file_extname,
  ['${cwd}'] = function()
    return vim.fn.getcwd()
  end,
  ['${pathSeparator}'] = function()
    return package.config:sub(1, 1) -- Get OS path separator
  end,
}

-- Substitute variables in a string
local function substitute_string(str)
  if type(str) ~= 'string' then
    return str
  end

  local result = str

  -- Replace simple variables (non-capturing)
  for pattern, resolver in pairs(resolvers) do
    local escaped_pattern = pattern:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
    local value = resolver()
    result = result:gsub(escaped_pattern, value or '')
  end

  -- Replace environment variables (${env:VAR_NAME})
  result = result:gsub('%${env:([%w_]+)}', function(env_var)
    return os.getenv(env_var) or ''
  end)

  return result
end

-- Recursively substitute variables in a config table
function M.substitute(config)
  if not config then
    return config
  end

  local function substitute_recursive(tbl)
    if type(tbl) ~= 'table' then
      return tbl
    end

    local result = {}

    for k, v in pairs(tbl) do
      if type(v) == 'string' then
        result[k] = substitute_string(v)
      elseif type(v) == 'table' then
        result[k] = substitute_recursive(v)
      else
        result[k] = v
      end
    end

    return result
  end

  return substitute_recursive(vim.deepcopy(config))
end

-- Substitute variables in a single string (public API)
function M.substitute_string(str)
  return substitute_string(str)
end

return M
