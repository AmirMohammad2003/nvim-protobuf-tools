-- Filetype detection for Protocol Buffer files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.proto',
  callback = function()
    vim.bo.filetype = 'proto'
  end,
})
