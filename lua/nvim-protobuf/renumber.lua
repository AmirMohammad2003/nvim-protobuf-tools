-- Field and enum renumbering for nvim-protobuf
local M = {}

-- Renumber fields and enums in current proto file
function M.renumber()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Ask user what to renumber
  local choice = vim.fn.confirm('What to renumber?', '&Fields\n&Enums\n&Both', 1)

  if choice == 0 then
    return
  end

  local renumber_fields = choice == 1 or choice == 3
  local renumber_enums = choice == 2 or choice == 3

  local modified_lines = {}
  local in_message = false
  local in_enum = false
  local field_counter = 1
  local enum_counter = 0

  for _, line in ipairs(lines) do
    local new_line = line

    -- Track context
    if line:match('^%s*message%s+') then
      in_message = true
      in_enum = false
      field_counter = 1
    elseif line:match('^%s*enum%s+') then
      in_enum = true
      in_message = false
      enum_counter = 0
    elseif line:match('^%s*}') then
      in_message = false
      in_enum = false
    end

    -- Renumber fields in messages
    if renumber_fields and in_message and not in_enum then
      -- Match field definition: type name = number;
      local before, after = line:match('(.-)=%s*%d+%s*(;.*)$')

      if before and after and not line:match('^%s*//') then -- Skip comments
        new_line = string.format('%s= %d%s', before, field_counter, after)
        field_counter = field_counter + 1
      end
    end

    -- Renumber enum values
    if renumber_enums and in_enum then
      local before, after = line:match('(.-)=%s*%d+%s*(;.*)$')

      if before and after and not line:match('^%s*//') then -- Skip comments
        new_line = string.format('%s= %d%s', before, enum_counter, after)
        enum_counter = enum_counter + 1
      end
    end

    table.insert(modified_lines, new_line)
  end

  -- Apply changes
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, modified_lines)
  require('nvim-protobuf.utils').notify('Renumbering complete', vim.log.levels.INFO)
end

return M
