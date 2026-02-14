-- Linting integration for nvim-protobuf
-- Supports buf, protolint, and api-linter
local M = {}

-- Linter configurations
local linters = {
  buf = {
    cmd = 'buf',
    args = function(file)
      return { 'lint', file }
    end,
    parse = M.parse_buf_output,
  },
  protolint = {
    cmd = 'protolint',
    args = function(file)
      return { 'lint', file }
    end,
    parse = M.parse_protolint_output,
  },
  ['api-linter'] = {
    cmd = 'api-linter',
    args = function(file)
      return { file }
    end,
    parse = M.parse_api_linter_output,
  },
}

-- Parse buf linter output
function M.parse_buf_output(output, file_path)
  local diagnostics = {}

  -- Buf format: file:line:col:message
  for line in output:gmatch('[^\n]+') do
    local lnum, col, message = line:match(':(%d+):(%d+):(.+)')

    if lnum then
      table.insert(diagnostics, {
        filename = file_path,
        lnum = tonumber(lnum) - 1,
        col = tonumber(col) - 1,
        severity = vim.diagnostic.severity.WARN,
        message = vim.trim(message),
        source = 'buf',
      })
    end
  end

  return diagnostics
end

-- Parse protolint output
function M.parse_protolint_output(output, file_path)
  local diagnostics = {}

  -- Protolint format: [file:line:col] message
  for line in output:gmatch('[^\n]+') do
    local lnum, col, message = line:match('%[.-:(%d+):(%d+)%]%s*(.+)')

    if lnum then
      table.insert(diagnostics, {
        filename = file_path,
        lnum = tonumber(lnum) - 1,
        col = tonumber(col) - 1,
        severity = vim.diagnostic.severity.WARN,
        message = vim.trim(message),
        source = 'protolint',
      })
    end
  end

  return diagnostics
end

-- Parse api-linter output
function M.parse_api_linter_output(output, file_path)
  local diagnostics = {}

  -- API linter format: file:line:col: message
  for line in output:gmatch('[^\n]+') do
    local lnum, col, message = line:match(':(%d+):(%d+):%s*(.+)')

    if lnum then
      table.insert(diagnostics, {
        filename = file_path,
        lnum = tonumber(lnum) - 1,
        col = tonumber(col) - 1,
        severity = vim.diagnostic.severity.WARN,
        message = vim.trim(message),
        source = 'api-linter',
      })
    end
  end

  return diagnostics
end

-- Run linter on proto file
function M.lint(file_path)
  file_path = file_path or vim.api.nvim_buf_get_name(0)

  if file_path == '' then
    require('nvim-protobuf.utils').notify('No file to lint', vim.log.levels.ERROR)
    return
  end

  local utils = require('nvim-protobuf.utils')
  local config = require('nvim-protobuf.config').get()
  local linter_config = config.externalLinter
  local linter_name = linter_config.linter

  if linter_name == 'none' then
    utils.notify('No linter configured', vim.log.levels.WARN)
    return
  end

  local linter = linters[linter_name]

  if not linter then
    utils.notify('Unknown linter: ' .. linter_name, vim.log.levels.ERROR)
    return
  end

  -- Get linter-specific path from config
  local linter_path = linter.cmd
  if linter_name == 'buf' and linter_config.bufPath then
    linter_path = linter_config.bufPath
  elseif linter_name == 'protolint' and linter_config.protolintPath then
    linter_path = linter_config.protolintPath
  elseif linter_name == 'api-linter' and linter_config.apiLinterPath then
    linter_path = linter_config.apiLinterPath
  end

  -- Check if linter exists
  if not utils.command_exists(linter_path) then
    utils.notify(
      string.format('%s not found. Please install it to use linting.', linter_path),
      vim.log.levels.ERROR
    )
    return
  end

  local job = require('nvim-protobuf.job')

  -- Build command
  local cmd = { linter_path }

  -- Add config file if specified
  local config_path = nil
  if linter_name == 'buf' and linter_config.bufConfigPath and linter_config.bufConfigPath ~= '' then
    config_path = linter_config.bufConfigPath
    table.insert(cmd, '--config')
    table.insert(cmd, config_path)
  elseif linter_name == 'protolint' and linter_config.protolintConfigPath and linter_config.protolintConfigPath ~= '' then
    config_path = linter_config.protolintConfigPath
    table.insert(cmd, '-config_path')
    table.insert(cmd, config_path)
  elseif linter_name == 'api-linter' and linter_config.apiLinterConfigPath and linter_config.apiLinterConfigPath ~= '' then
    config_path = linter_config.apiLinterConfigPath
    table.insert(cmd, '--config')
    table.insert(cmd, config_path)
  end

  -- Add linter-specific arguments
  vim.list_extend(cmd, linter.args(file_path))

  -- Clear previous linter diagnostics
  require('nvim-protobuf.diagnostics').clear('linter')

  -- Log command if debug enabled
  if config.debug and config.debug.verboseLogging then
    utils.notify('Running: ' .. table.concat(cmd, ' '), vim.log.levels.DEBUG)
  end

  -- Execute linter
  job.run({
    cmd = cmd,
    cwd = utils.find_workspace_root(),
    on_exit = function(code, stdout, stderr)
      local output = stdout .. stderr

      if code == 0 and output:match('^%s*$') then
        utils.notify('Linting passed', vim.log.levels.INFO)
        require('nvim-protobuf.diagnostics').clear_all_for_source('linter')
      else
        local diagnostics = linter.parse(output, file_path)
        if #diagnostics > 0 then
          require('nvim-protobuf.diagnostics').set(diagnostics, 'linter')
          utils.notify(string.format('Found %d linting issue(s)', #diagnostics), vim.log.levels.WARN)
        else
          utils.notify('Linting completed', vim.log.levels.INFO)
        end
      end
    end,
  })
end

return M
