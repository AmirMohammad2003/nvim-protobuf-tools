-- Plugin entry point for nvim-protobuf
-- Registers user commands

-- Check if plugin already loaded
if vim.g.loaded_nvim_protobuf then
  return
end
vim.g.loaded_nvim_protobuf = 1

-- Register :ProtobufCompile command
vim.api.nvim_create_user_command('ProtobufCompile', function(opts)
  local file_path = opts.args ~= '' and opts.args or nil
  require('nvim-protobuf').compile(file_path)
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Compile current or specified proto file',
})

-- Register :ProtobufCompileAll command
vim.api.nvim_create_user_command('ProtobufCompileAll', function()
  require('nvim-protobuf').compile_all()
end, {
  desc = 'Compile all proto files in workspace',
})

-- Register :ProtobufLint command
vim.api.nvim_create_user_command('ProtobufLint', function()
  require('nvim-protobuf').lint()
end, {
  desc = 'Run configured linter on current proto file',
})

-- Register :ProtobufFormat command
vim.api.nvim_create_user_command('ProtobufFormat', function()
  require('nvim-protobuf').format()
end, {
  desc = 'Format current proto file',
})

-- Register :ProtobufBreaking command
vim.api.nvim_create_user_command('ProtobufBreaking', function(opts)
  local git_ref = opts.args ~= '' and opts.args or nil
  require('nvim-protobuf').check_breaking(git_ref)
end, {
  nargs = '?',
  desc = 'Check breaking changes against git ref',
})

-- Register :ProtobufRenumber command
vim.api.nvim_create_user_command('ProtobufRenumber', function()
  require('nvim-protobuf').renumber()
end, {
  desc = 'Renumber fields and enums in current proto file',
})

-- Register :ProtobufGraph command
vim.api.nvim_create_user_command('ProtobufGraph', function()
  require('nvim-protobuf').show_graph()
end, {
  desc = 'Show schema dependency graph',
})

-- Register :ProtobufOrganizeImports command
vim.api.nvim_create_user_command('ProtobufOrganizeImports', function()
  require('nvim-protobuf').organize_imports()
end, {
  desc = 'Organize and sort imports',
})

-- Register :ProtobufReloadConfig command
vim.api.nvim_create_user_command('ProtobufReloadConfig', function()
  require('nvim-protobuf').reload_config()
end, {
  desc = 'Reload nvim-protobuf configuration',
})
