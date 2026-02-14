-- Protoc compilation logic for nvim-protobuf
local M = {}

-- Parse protoc error output into diagnostics
-- Supports multiple protoc error formats
local function parse_protoc_errors(stderr, file_path)
  local diagnostics = {}

  for line in stderr:gmatch('[^\n]+') do
    -- Format 1: file:line:col: error: message
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
      -- Format 2: file:line: error: message (no column)
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
      else
        -- Format 3: file: error: message (no line number)
        match_file, message = line:match('([^:]+):%s*(%w+:%s*.+)')

        if match_file and message then
          table.insert(diagnostics, {
            filename = match_file,
            lnum = 0,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = vim.trim(message),
            source = 'protoc',
          })
        end
      end
    end
  end

  return diagnostics
end

-- Check if file should be excluded based on patterns
local function should_exclude(file_path, exclude_patterns)
  for _, pattern in ipairs(exclude_patterns) do
    if file_path:match(pattern) then
      return true
    end
  end
  return false
end

-- Extract proto_path from options if not in includes
local function extract_proto_paths(options)
  local paths = {}

  for _, opt in ipairs(options) do
    -- Match --proto_path=<path> or -I<path>
    local path = opt:match('^%-%-proto_path=(.+)')
    if not path then
      path = opt:match('^%-I(.+)')
    end

    if path then
      table.insert(paths, path)
    end
  end

  return paths
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

  -- Check if file should be excluded
  if should_exclude(file_path, config.protoc.excludePatterns or {}) then
    utils.notify('File excluded from compilation: ' .. file_path, vim.log.levels.INFO)
    return
  end

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

  -- Determine include paths: prefer config.includes, fall back to extracting from options
  local includes = config.includes or {}
  if #includes == 0 then
    includes = extract_proto_paths(config.protoc.options or {})
  end

  -- Add include paths
  for _, include in ipairs(includes) do
    table.insert(cmd, '--proto_path=' .. include)
  end

  -- Add workspace root as include path if not already present
  local workspace_root = utils.find_workspace_root()
  local has_workspace_path = false
  for _, include in ipairs(includes) do
    if include == workspace_root or include == '.' then
      has_workspace_path = true
      break
    end
  end

  if not has_workspace_path then
    table.insert(cmd, '--proto_path=' .. workspace_root)
  end

  -- Add user-configured options (but skip --proto_path options if already processed)
  for _, option in ipairs(config.protoc.options or {}) do
    if not option:match('^%-%-proto_path=') and not option:match('^%-I') then
      table.insert(cmd, option)
    end
  end

  -- Add the file to compile (use absolute path if configured)
  if config.protoc.useAbsolutePath then
    table.insert(cmd, vim.fn.fnamemodify(file_path, ':p'))
  else
    table.insert(cmd, file_path)
  end

  -- Clear previous protoc diagnostics
  require('nvim-protobuf.diagnostics').clear('protoc')

  -- Log command if debug enabled
  if config.debug and config.debug.verboseLogging then
    utils.notify('Running: ' .. table.concat(cmd, ' '), vim.log.levels.DEBUG)
  end

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
  local config = require('nvim-protobuf.config').get()
  local workspace_root = utils.find_workspace_root()

  -- Determine search path
  local search_path = workspace_root
  if config.protoSrcsDir and config.protoSrcsDir ~= '' then
    search_path = workspace_root .. '/' .. config.protoSrcsDir
  end

  -- Find all .proto files
  local proto_files = vim.fn.globpath(search_path, '**/*.proto', false, true)

  if #proto_files == 0 then
    utils.notify('No proto files found in workspace', vim.log.levels.WARN)
    return
  end

  -- Filter out excluded files
  local exclude_patterns = config.protoc.excludePatterns or {}
  local files_to_compile = {}

  for _, file in ipairs(proto_files) do
    if not should_exclude(file, exclude_patterns) then
      table.insert(files_to_compile, file)
    end
  end

  if #files_to_compile == 0 then
    utils.notify('All proto files are excluded', vim.log.levels.WARN)
    return
  end

  utils.notify(string.format('Compiling %d proto files...', #files_to_compile), vim.log.levels.INFO)

  -- Compile each file
  for _, file in ipairs(files_to_compile) do
    M.compile(file)
  end
end

return M
