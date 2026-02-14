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

  -- Protoc settings
  if vscode_settings['protobuf.protoc.path'] then
    config.protoc = config.protoc or {}
    config.protoc.path = vscode_settings['protobuf.protoc.path']
  end

  if vscode_settings['protobuf.protoc.options'] then
    config.protoc = config.protoc or {}
    config.protoc.options = vscode_settings['protobuf.protoc.options']
  end

  if vscode_settings['protobuf.protoc.compileOnSave'] ~= nil then
    config.protoc = config.protoc or {}
    config.protoc.compileOnSave = vscode_settings['protobuf.protoc.compileOnSave']
  end

  -- Include paths
  if vscode_settings['protobuf.includes'] then
    config.includes = vscode_settings['protobuf.includes']
  end

  -- Format settings
  if vscode_settings['protobuf.formatOnSave'] ~= nil then
    config.formatOnSave = vscode_settings['protobuf.formatOnSave']
  end

  if vscode_settings['protobuf.formatter.enabled'] ~= nil then
    config.formatter = config.formatter or {}
    config.formatter.enabled = vscode_settings['protobuf.formatter.enabled']
  end

  if vscode_settings['protobuf.formatter.insertEmptyLineBetweenDefinitions'] ~= nil then
    config.formatter = config.formatter or {}
    config.formatter.insertEmptyLineBetweenDefinitions = vscode_settings['protobuf.formatter.insertEmptyLineBetweenDefinitions']
  end

  if vscode_settings['protobuf.formatter.maxEmptyLines'] then
    config.formatter = config.formatter or {}
    config.formatter.maxEmptyLines = vscode_settings['protobuf.formatter.maxEmptyLines']
  end

  -- Clang-format settings
  if vscode_settings['protobuf.clangFormat.enabled'] ~= nil then
    config.clangFormat = config.clangFormat or {}
    config.clangFormat.enabled = vscode_settings['protobuf.clangFormat.enabled']
  end

  if vscode_settings['protobuf.clangFormat.style'] then
    config.clangFormat = config.clangFormat or {}
    config.clangFormat.style = vscode_settings['protobuf.clangFormat.style']
  end

  -- External linter settings
  if vscode_settings['protobuf.externalLinter.linter'] then
    config.externalLinter = config.externalLinter or {}
    config.externalLinter.linter = vscode_settings['protobuf.externalLinter.linter']
  end

  if vscode_settings['protobuf.externalLinter.enabled'] ~= nil then
    config.externalLinter = config.externalLinter or {}
    config.externalLinter.enabled = vscode_settings['protobuf.externalLinter.enabled']
  end

  if vscode_settings['protobuf.externalLinter.runOnSave'] ~= nil then
    config.externalLinter = config.externalLinter or {}
    config.externalLinter.runOnSave = vscode_settings['protobuf.externalLinter.runOnSave']
  end

  -- Breaking change settings
  if vscode_settings['protobuf.breaking.enabled'] ~= nil then
    config.breaking = config.breaking or {}
    config.breaking.enabled = vscode_settings['protobuf.breaking.enabled']
  end

  if vscode_settings['protobuf.breaking.againstGitRef'] then
    config.breaking = config.breaking or {}
    config.breaking.againstGitRef = vscode_settings['protobuf.breaking.againstGitRef']
  end

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
