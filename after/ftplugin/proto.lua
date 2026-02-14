-- Buffer-local settings and autocommands for proto files
-- This runs after Neovim's default ftplugin

-- Avoid loading twice for the same buffer
if vim.b.did_nvim_protobuf_ftplugin then
  return
end
vim.b.did_nvim_protobuf_ftplugin = 1

-- Buffer-local settings
vim.bo.commentstring = '// %s'
vim.bo.comments = 's1:/*,mb:*,ex:*/,://'

-- Get configuration
local config = require('nvim-protobuf.config')

-- Set up compile-on-save autocommand
if config.is_compile_on_save_enabled() then
  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = 0,
    callback = function()
      require('nvim-protobuf').compile()
    end,
    desc = 'Compile proto on save',
  })
end

-- Set up format-on-save autocommand
if config.is_format_on_save_enabled() then
  vim.api.nvim_create_autocmd('BufWritePre', {
    buffer = 0,
    callback = function()
      require('nvim-protobuf').format()
    end,
    desc = 'Format proto on save',
  })
end

-- Set up lint-on-save autocommand
if config.is_lint_on_save_enabled() then
  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = 0,
    callback = function()
      require('nvim-protobuf').lint()
    end,
    desc = 'Lint proto on save',
  })
end
