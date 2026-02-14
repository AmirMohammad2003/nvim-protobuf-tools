-- Configuration management for nvim-protobuf
-- Handles merging of default, user, and VSCode settings with proper precedence
local M = {}

-- Default configuration matching VSCode extension defaults
local defaults = {
  -- Protoc compilation settings
  protoc = {
    path = 'protoc',
    options = {},
    compileOnSave = false,
    useAbsolutePath = false,
    excludePatterns = {},
  },

  -- Import search paths
  includes = {},
  protoSrcsDir = '',

  -- Formatting settings
  formatOnSave = false,
  indentSize = 2,
  useTabIndent = false,
  maxLineLength = 120,

  formatter = {
    enabled = true,
    preset = 'minimal', -- 'minimal', 'google', 'buf', 'custom'
    type = 'builtin', -- 'builtin', 'clang-format', 'buf'
    alignFields = true,
    insertEmptyLineBetweenDefinitions = true,
    maxEmptyLines = 1,
    preserveMultiLineFields = false,
  },

  -- Clang-format settings
  clangFormat = {
    enabled = false,
    path = 'clang-format',
    style = 'file',
    fallbackStyle = 'Google',
    configPath = '',
  },

  -- Import organization
  organizeImports = {
    enabled = true,
    groupByCategory = true,
  },

  -- External linter settings
  externalLinter = {
    enabled = false,
    linter = 'none', -- 'none', 'buf', 'protolint', 'api-linter'
    runOnSave = true,

    -- Tool paths
    bufPath = 'buf',
    protolintPath = 'protolint',
    apiLinterPath = 'api-linter',

    -- Config file paths
    bufConfigPath = '',
    protolintConfigPath = '',
    apiLinterConfigPath = '',
  },

  -- Buf CLI settings
  buf = {
    path = 'buf',
    useManaged = false,
  },

  -- Breaking change detection
  breaking = {
    enabled = false,
    againstStrategy = 'git', -- 'git', 'file', 'none'
    againstGitRef = 'HEAD~1',
    againstFilePath = '',
  },

  -- Field renumbering
  renumber = {
    startNumber = 1,
    increment = 1,
    preserveReserved = true,
    skipInternalRange = true, -- Skip 19000-19999
    autoSuggestNext = true,
    onFormat = false,
  },

  -- Diagnostic settings
  diagnostics = {
    enabled = true,
    useBuiltIn = true,

    -- Diagnostic types
    namingConventions = true,
    referenceChecks = true,
    importChecks = true,
    fieldTagChecks = true,
    duplicateFieldChecks = true,
    discouragedConstructs = true,
    deprecatedUsage = true,
    unusedSymbols = false,
    circularDependencies = true,
    documentationComments = true,
    breakingChanges = false,

    -- Severity levels
    severity = {
      namingConventions = vim.diagnostic.severity.WARN,
      referenceErrors = vim.diagnostic.severity.ERROR,
      fieldTagIssues = vim.diagnostic.severity.ERROR,
      discouragedConstructs = vim.diagnostic.severity.WARN,
      nonCanonicalImportPath = vim.diagnostic.severity.WARN,
      breakingChanges = vim.diagnostic.severity.ERROR,
    },

    -- Neovim-specific
    virtual_text = true,
    signs = true,
  },

  -- Completion settings
  completion = {
    autoImport = true,
    includeGoogleTypes = true,
  },

  -- Hover settings
  hover = {
    showFieldNumbers = true,
    showDocumentation = true,
  },

  -- Code generation
  codegen = {
    generateOnSave = false,
    tool = 'buf', -- 'protoc', 'buf'
    profiles = {},
  },

  -- Parser settings
  parser = 'tree-sitter', -- 'tree-sitter', 'legacy'

  -- Debug settings
  debug = {
    verboseLogging = false,
    logLevel = 'info', -- 'error', 'warn', 'info', 'debug', 'verbose'
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
