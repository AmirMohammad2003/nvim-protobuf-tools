-- Configuration management for nvim-protobuf
-- Handles merging of default, user, and VSCode settings with proper precedence
local M = {}

-- Default configuration matching VSCode extension defaults
local defaults = {
  protoc = {
    path = 'protoc',
    options = {},
    compileOnSave = false,
  },
  includes = {},
  formatOnSave = false,
  formatter = {
    enabled = true,
    type = 'builtin', -- 'builtin', 'clang-format', 'buf'
    insertEmptyLineBetweenDefinitions = true,
    maxEmptyLines = 1,
  },
  clangFormat = {
    enabled = false,
    style = 'file',
  },
  externalLinter = {
    linter = 'none', -- 'none', 'buf', 'protolint', 'api-linter'
    enabled = false,
    runOnSave = false,
  },
  breaking = {
    enabled = false,
    againstGitRef = 'main',
  },
  -- Neovim-specific additions
  diagnostics = {
    enabled = true,
    virtual_text = true,
    signs = true,
  },
}

-- User configuration (set via setup())
local user_config = nil

-- Initialize plugin with user configuration
function M.setup(config)
  user_config = config or {}
end

-- Get final merged configuration
-- Precedence: VSCode settings > User config > Defaults
function M.get()
  -- Start with defaults
  local config = vim.deepcopy(defaults)

  -- Merge user config if available
  if user_config then
    config = vim.tbl_deep_extend('force', config, user_config)
  end

  -- Look for and merge VSCode settings
  local vscode = require('nvim-protobuf.vscode')
  local vscode_config = vscode.parse()

  if vscode_config then
    config = vim.tbl_deep_extend('force', config, vscode_config)
  end

  -- Apply variable substitution
  local variables = require('nvim-protobuf.variables')
  config = variables.substitute(config)

  return config
end

-- Get a specific configuration value by path
-- Example: M.get_value('protoc.path') or M.get_value('externalLinter.linter')
function M.get_value(path)
  local config = M.get()
  local keys = vim.split(path, '.', { plain = true })

  local value = config
  for _, key in ipairs(keys) do
    if type(value) ~= 'table' then
      return nil
    end
    value = value[key]
  end

  return value
end

-- Determine formatter type based on config
function M.get_formatter_type()
  local config = M.get()

  if not config.formatter.enabled then
    return 'none'
  end

  -- If clang-format is explicitly enabled, use it
  if config.clangFormat and config.clangFormat.enabled then
    return 'clang-format'
  end

  -- Otherwise use configured formatter type
  return config.formatter.type or 'builtin'
end

-- Check if compile-on-save is enabled
function M.is_compile_on_save_enabled()
  local config = M.get()
  return config.protoc and config.protoc.compileOnSave == true
end

-- Check if format-on-save is enabled
function M.is_format_on_save_enabled()
  local config = M.get()
  return config.formatOnSave == true and config.formatter.enabled == true
end

-- Check if lint-on-save is enabled
function M.is_lint_on_save_enabled()
  local config = M.get()
  return config.externalLinter
      and config.externalLinter.runOnSave == true
      and config.externalLinter.linter ~= 'none'
end

-- Reload configuration (clears caches)
function M.reload()
  local vscode = require('nvim-protobuf.vscode')
  vscode.clear_cache()
  return M.get()
end

return M
