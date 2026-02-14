-- nvim-protobuf: Protocol Buffers development tools for Neovim
-- Main module and public API
local M = {}

-- Initialize plugin with user configuration
-- @param user_config table: User configuration options
function M.setup(user_config)
  local config = require('nvim-protobuf.config')
  config.setup(user_config)
end

-- Compile proto file(s)
-- @param file_path string|nil: Path to proto file (defaults to current buffer)
function M.compile(file_path)
  require('nvim-protobuf.compile').compile(file_path)
end

-- Compile all proto files in workspace
function M.compile_all()
  require('nvim-protobuf.compile').compile_all()
end

-- Run external linter on current proto file
function M.lint()
  require('nvim-protobuf.lint').lint()
end

-- Format current proto file
function M.format()
  require('nvim-protobuf.format').format()
end

-- Check for breaking changes against git ref
-- @param git_ref string|nil: Git reference to compare against (defaults to config)
function M.check_breaking(git_ref)
  require('nvim-protobuf.breaking').check(git_ref)
end

-- Renumber fields and enums in current proto file
function M.renumber()
  require('nvim-protobuf.renumber').renumber()
end

-- Show schema dependency graph
function M.show_graph()
  require('nvim-protobuf.graph').show()
end

-- Reload configuration (clears caches)
function M.reload_config()
  require('nvim-protobuf.config').reload()
  require('nvim-protobuf.utils').notify('Configuration reloaded', vim.log.levels.INFO)
end

return M
