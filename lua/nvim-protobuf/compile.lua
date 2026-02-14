-- Protoc compilation logic for nvim-protobuf
local M = {}

-- Parse protoc error output into diagnostics
-- Format: file:line:col: error: message
local function parse_protoc_errors(stderr, file_path)
  local diagnostics = {}

  for line in stderr:gmatch('[^\n]+') do
    -- Try to parse protoc error format
    local match_file, lnum, col, severity, message = line:match('([^:]+):(%d+):(%d+):%s*(%w+):%s*(.+)')

    if match_file and lnum then
      table.insert(diagnostics, {
        filename = match_file,
        lnum = tonumber(lnum) - 1, -- 0-indexed
        col = tonumber(col) - 1,
        severity = severity == 'error' and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
        message = vim.trim(message),
        source = 'protoc',
      })
    else
      -- Try alternate format without column: file:line: error: message
      match_file, lnum, severity, message = line:match('([^:]+):(%d+):%s*(%w+):%s*(.+)')

      if match_file and lnum then
        table.insert(diagnostics, {
          filename = match_file,
          lnum = tonumber(lnum) - 1,
          col = 0,
          severity = severity == 'error' and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
          message = vim.trim(message),
          source = 'protoc',
        })
      end
    end
  end

  return diagnostics
end

-- Compile a single proto file
-- @param file_path string|nil: Path to proto file (defaults to current buffer)
function M.compile(file_path)
  file_path = file_path or vim.api.nvim_buf_get_name(0)

  if file_path == '' then
    require('nvim-protobuf.utils').notify('No file to compile', vim.log.levels.ERROR)
    return
  end

  local utils = require('nvim-protobuf.utils')

  if not utils.is_proto_file(file_path) then
    utils.notify('Not a proto file: ' .. file_path, vim.log.levels.ERROR)
    return
  end

  local config = require('nvim-protobuf.config').get()
  local job = require('nvim-protobuf.job')

  -- Check if protoc exists
  if not utils.command_exists(config.protoc.path) then
    utils.notify(
      'protoc not found. Please install Protocol Buffers compiler: https://protobuf.dev/downloads/',
      vim.log.levels.ERROR
    )
    return
  end

  -- Build protoc command
  local cmd = { config.protoc.path }

  -- Add include paths
  for _, include in ipairs(config.includes) do
    table.insert(cmd, '--proto_path=' .. include)
  end

  -- Add user-configured options
  for _, option in ipairs(config.protoc.options) do
    table.insert(cmd, option)
  end

  -- Add the file to compile
  table.insert(cmd, file_path)

  local workspace_root = utils.find_workspace_root()

  -- Clear previous protoc diagnostics
  require('nvim-protobuf.diagnostics').clear('protoc')

  -- Execute protoc
  job.run({
    cmd = cmd,
    cwd = workspace_root,
    on_exit = function(code, stdout, stderr)
      if code == 0 then
        utils.notify('Compilation successful', vim.log.levels.INFO)
        -- Clear any previous diagnostics
        require('nvim-protobuf.diagnostics').clear_all_for_source('protoc')
      else
        utils.notify('Compilation failed', vim.log.levels.ERROR)
        -- Parse errors and show as diagnostics
        local diagnostics = parse_protoc_errors(stderr, file_path)
        if #diagnostics > 0 then
          require('nvim-protobuf.diagnostics').set(diagnostics, 'protoc')
        else
          -- If we couldn't parse diagnostics, at least show the error
          utils.notify('Protoc error: ' .. stderr, vim.log.levels.ERROR)
        end
      end
    end,
  })
end

-- Compile all proto files in workspace
function M.compile_all()
  local utils = require('nvim-protobuf.utils')
  local workspace_root = utils.find_workspace_root()

  -- Find all .proto files
  local proto_files = vim.fn.globpath(workspace_root, '**/*.proto', false, true)

  if #proto_files == 0 then
    utils.notify('No proto files found in workspace', vim.log.levels.WARN)
    return
  end

  utils.notify(string.format('Compiling %d proto files...', #proto_files), vim.log.levels.INFO)

  -- Compile each file
  for _, file in ipairs(proto_files) do
    M.compile(file)
  end
end

return M
