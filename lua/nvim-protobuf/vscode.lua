-- VSCode settings parser for nvim-protobuf
-- Reads and parses .vscode/settings.json with protobuf.* configuration
local M = {}

-- Cache parsed settings per workspace
local cache = {}

-- Strip JSON comments (JSONC support)
local function strip_json_comments(json_str)
  -- Remove single-line comments (// ...)
  json_str = json_str:gsub('//[^\n]*', '')

  -- Remove multi-line comments (/* ... */)
  json_str = json_str:gsub('/%*.-%*/', '')

  return json_str
end

-- Map VSCode flat settings to nested config structure
local function map_vscode_to_config(vscode_settings)
  local config = {}

  -- Helper to set nested value
  local function set_nested(path, value)
    if value == nil then
      return
    end

    local keys = vim.split(path, '.', { plain = true })
    local tbl = config

    for i = 1, #keys - 1 do
      local key = keys[i]
      tbl[key] = tbl[key] or {}
      tbl = tbl[key]
    end

    tbl[keys[#keys]] = value
  end

  -- Protoc settings
  set_nested('protoc.path', vscode_settings['protobuf.protoc.path'])
  set_nested('protoc.options', vscode_settings['protobuf.protoc.options'])
  set_nested('protoc.compileOnSave', vscode_settings['protobuf.protoc.compileOnSave'])
  set_nested('protoc.useAbsolutePath', vscode_settings['protobuf.protoc.useAbsolutePath'])
  set_nested('protoc.excludePatterns', vscode_settings['protobuf.protoc.excludePatterns'])

  -- Include paths
  set_nested('includes', vscode_settings['protobuf.includes'])
  set_nested('protoSrcsDir', vscode_settings['protobuf.protoSrcsDir'])

  -- Format settings
  set_nested('formatOnSave', vscode_settings['protobuf.formatOnSave'])
  set_nested('indentSize', vscode_settings['protobuf.indentSize'])
  set_nested('useTabIndent', vscode_settings['protobuf.useTabIndent'])
  set_nested('maxLineLength', vscode_settings['protobuf.maxLineLength'])

  -- Formatter settings
  set_nested('formatter.enabled', vscode_settings['protobuf.formatter.enabled'])
  set_nested('formatter.preset', vscode_settings['protobuf.formatter.preset'])
  set_nested('formatter.alignFields', vscode_settings['protobuf.formatter.alignFields'])
  set_nested('formatter.insertEmptyLineBetweenDefinitions', vscode_settings['protobuf.formatter.insertEmptyLineBetweenDefinitions'])
  set_nested('formatter.maxEmptyLines', vscode_settings['protobuf.formatter.maxEmptyLines'])
  set_nested('formatter.preserveMultiLineFields', vscode_settings['protobuf.formatter.preserveMultiLineFields'])

  -- Clang-format settings
  set_nested('clangFormat.enabled', vscode_settings['protobuf.clangFormat.enabled'])
  set_nested('clangFormat.path', vscode_settings['protobuf.clangFormat.path'])
  set_nested('clangFormat.style', vscode_settings['protobuf.clangFormat.style'])
  set_nested('clangFormat.fallbackStyle', vscode_settings['protobuf.clangFormat.fallbackStyle'])
  set_nested('clangFormat.configPath', vscode_settings['protobuf.clangFormat.configPath'])

  -- Import organization
  set_nested('organizeImports.enabled', vscode_settings['protobuf.organizeImports.enabled'])
  set_nested('organizeImports.groupByCategory', vscode_settings['protobuf.organizeImports.groupByCategory'])

  -- External linter settings
  set_nested('externalLinter.enabled', vscode_settings['protobuf.externalLinter.enabled'])
  set_nested('externalLinter.linter', vscode_settings['protobuf.externalLinter.linter'])
  set_nested('externalLinter.runOnSave', vscode_settings['protobuf.externalLinter.runOnSave'])
  set_nested('externalLinter.bufPath', vscode_settings['protobuf.externalLinter.bufPath'])
  set_nested('externalLinter.protolintPath', vscode_settings['protobuf.externalLinter.protolintPath'])
  set_nested('externalLinter.apiLinterPath', vscode_settings['protobuf.externalLinter.apiLinterPath'])
  set_nested('externalLinter.bufConfigPath', vscode_settings['protobuf.externalLinter.bufConfigPath'])
  set_nested('externalLinter.protolintConfigPath', vscode_settings['protobuf.externalLinter.protolintConfigPath'])
  set_nested('externalLinter.apiLinterConfigPath', vscode_settings['protobuf.externalLinter.apiLinterConfigPath'])

  -- Buf CLI settings
  set_nested('buf.path', vscode_settings['protobuf.buf.path'])
  set_nested('buf.useManaged', vscode_settings['protobuf.buf.useManaged'])

  -- Breaking change settings
  set_nested('breaking.enabled', vscode_settings['protobuf.breaking.enabled'])
  set_nested('breaking.againstStrategy', vscode_settings['protobuf.breaking.againstStrategy'])
  set_nested('breaking.againstGitRef', vscode_settings['protobuf.breaking.againstGitRef'])
  set_nested('breaking.againstFilePath', vscode_settings['protobuf.breaking.againstFilePath'])

  -- Field renumbering
  set_nested('renumber.startNumber', vscode_settings['protobuf.renumber.startNumber'])
  set_nested('renumber.increment', vscode_settings['protobuf.renumber.increment'])
  set_nested('renumber.preserveReserved', vscode_settings['protobuf.renumber.preserveReserved'])
  set_nested('renumber.skipInternalRange', vscode_settings['protobuf.renumber.skipInternalRange'])
  set_nested('renumber.autoSuggestNext', vscode_settings['protobuf.renumber.autoSuggestNext'])
  set_nested('renumber.onFormat', vscode_settings['protobuf.renumber.onFormat'])

  -- Diagnostic settings
  set_nested('diagnostics.enabled', vscode_settings['protobuf.diagnostics.enabled'])
  set_nested('diagnostics.useBuiltIn', vscode_settings['protobuf.diagnostics.useBuiltIn'])
  set_nested('diagnostics.namingConventions', vscode_settings['protobuf.diagnostics.namingConventions'])
  set_nested('diagnostics.referenceChecks', vscode_settings['protobuf.diagnostics.referenceChecks'])
  set_nested('diagnostics.importChecks', vscode_settings['protobuf.diagnostics.importChecks'])
  set_nested('diagnostics.fieldTagChecks', vscode_settings['protobuf.diagnostics.fieldTagChecks'])
  set_nested('diagnostics.duplicateFieldChecks', vscode_settings['protobuf.diagnostics.duplicateFieldChecks'])
  set_nested('diagnostics.discouragedConstructs', vscode_settings['protobuf.diagnostics.discouragedConstructs'])
  set_nested('diagnostics.deprecatedUsage', vscode_settings['protobuf.diagnostics.deprecatedUsage'])
  set_nested('diagnostics.unusedSymbols', vscode_settings['protobuf.diagnostics.unusedSymbols'])
  set_nested('diagnostics.circularDependencies', vscode_settings['protobuf.diagnostics.circularDependencies'])
  set_nested('diagnostics.documentationComments', vscode_settings['protobuf.diagnostics.documentationComments'])
  set_nested('diagnostics.breakingChanges', vscode_settings['protobuf.diagnostics.breakingChanges'])

  -- Diagnostic severity mapping
  local severity_map = {
    error = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARN,
    information = vim.diagnostic.severity.INFO,
    hint = vim.diagnostic.severity.HINT,
  }

  local function map_severity(vscode_severity)
    return severity_map[vscode_severity] or vim.diagnostic.severity.WARN
  end

  if vscode_settings['protobuf.diagnostics.severity.namingConventions'] then
    set_nested('diagnostics.severity.namingConventions', map_severity(vscode_settings['protobuf.diagnostics.severity.namingConventions']))
  end

  if vscode_settings['protobuf.diagnostics.severity.referenceErrors'] then
    set_nested('diagnostics.severity.referenceErrors', map_severity(vscode_settings['protobuf.diagnostics.severity.referenceErrors']))
  end

  if vscode_settings['protobuf.diagnostics.severity.fieldTagIssues'] then
    set_nested('diagnostics.severity.fieldTagIssues', map_severity(vscode_settings['protobuf.diagnostics.severity.fieldTagIssues']))
  end

  if vscode_settings['protobuf.diagnostics.severity.discouragedConstructs'] then
    set_nested('diagnostics.severity.discouragedConstructs', map_severity(vscode_settings['protobuf.diagnostics.severity.discouragedConstructs']))
  end

  if vscode_settings['protobuf.diagnostics.severity.nonCanonicalImportPath'] then
    set_nested('diagnostics.severity.nonCanonicalImportPath', map_severity(vscode_settings['protobuf.diagnostics.severity.nonCanonicalImportPath']))
  end

  if vscode_settings['protobuf.diagnostics.severity.breakingChanges'] then
    set_nested('diagnostics.severity.breakingChanges', map_severity(vscode_settings['protobuf.diagnostics.severity.breakingChanges']))
  end

  -- Completion settings
  set_nested('completion.autoImport', vscode_settings['protobuf.completion.autoImport'])
  set_nested('completion.includeGoogleTypes', vscode_settings['protobuf.completion.includeGoogleTypes'])

  -- Hover settings
  set_nested('hover.showFieldNumbers', vscode_settings['protobuf.hover.showFieldNumbers'])
  set_nested('hover.showDocumentation', vscode_settings['protobuf.hover.showDocumentation'])

  -- Code generation
  set_nested('codegen.generateOnSave', vscode_settings['protobuf.codegen.generateOnSave'])
  set_nested('codegen.tool', vscode_settings['protobuf.codegen.tool'])
  set_nested('codegen.profiles', vscode_settings['protobuf.codegen.profiles'])

  -- Parser settings
  set_nested('parser', vscode_settings['protobuf.parser'])

  -- Debug settings
  set_nested('debug.verboseLogging', vscode_settings['protobuf.debug.verboseLogging'])
  set_nested('debug.logLevel', vscode_settings['protobuf.debug.logLevel'])

  return config
end

-- Parse .vscode/settings.json from workspace root
function M.parse()
  local utils = require('nvim-protobuf.utils')
  local workspace_root = utils.find_workspace_root()

  if not workspace_root then
    return nil
  end

  -- Check cache
  if cache[workspace_root] then
    return cache[workspace_root]
  end

  local settings_path = workspace_root .. '/.vscode/settings.json'

  -- Check if file exists
  if vim.fn.filereadable(settings_path) ~= 1 then
    return nil
  end

  -- Read file
  local ok, content = pcall(vim.fn.readfile, settings_path)
  if not ok then
    utils.notify('Failed to read .vscode/settings.json: ' .. content, vim.log.levels.WARN)
    return nil
  end

  -- Join lines and strip comments
  local json_str = table.concat(content, '\n')
  json_str = strip_json_comments(json_str)

  -- Parse JSON
  local parse_ok, settings = pcall(vim.json.decode, json_str)
  if not parse_ok then
    utils.notify('Failed to parse .vscode/settings.json: ' .. settings, vim.log.levels.WARN)
    return nil
  end

  -- Map VSCode settings to plugin config
  local config = map_vscode_to_config(settings)

  -- Cache result
  cache[workspace_root] = config

  return config
end

-- Clear cache (useful for testing or reloading config)
function M.clear_cache()
  cache = {}
end

-- Reload settings for current workspace
function M.reload()
  local utils = require('nvim-protobuf.utils')
  local workspace_root = utils.find_workspace_root()

  if workspace_root then
    cache[workspace_root] = nil
  end

  return M.parse()
end

return M
