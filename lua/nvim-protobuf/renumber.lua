-- Field and enum renumbering for nvim-protobuf
local M = {}

-- Check if a field number is in the reserved range (19000-19999)
local function is_internal_range(num)
  return num >= 19000 and num <= 19999
end

-- Get next valid field number (skipping internal range if configured)
local function get_next_field_number(current, increment, skip_internal)
  local next_num = current + increment

  if skip_internal and is_internal_range(next_num) then
    -- Skip to 20000
    return 20000
  end

  return next_num
end

-- Parse reserved field ranges from proto
local function parse_reserved_fields(lines)
  local reserved = {}

  for _, line in ipairs(lines) do
    -- Match: reserved 2, 15, 9 to 11;
    local numbers = line:match('^%s*reserved%s+([^;]+);')

    if numbers then
      for num in numbers:gmatch('%d+') do
        reserved[tonumber(num)] = true
      end

      -- Match ranges: 9 to 11
      for start_num, end_num in numbers:gmatch('(%d+)%s+to%s+(%d+)') do
        for i = tonumber(start_num), tonumber(end_num) do
          reserved[i] = true
        end
      end
    end
  end

  return reserved
end

-- Renumber fields and enums in current proto file
function M.renumber()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local config = require('nvim-protobuf.config').get()
  local renumber_config = config.renumber or {}

  -- Ask user what to renumber
  local choice = vim.fn.confirm('What to renumber?', '&Fields\n&Enums\n&Both', 1)

  if choice == 0 then
    return
  end

  local renumber_fields = choice == 1 or choice == 3
  local renumber_enums = choice == 2 or choice == 3

  -- Parse reserved fields if needed
  local reserved = {}
  if renumber_config.preserveReserved then
    reserved = parse_reserved_fields(lines)
  end

  local modified_lines = {}
  local in_message = false
  local in_enum = false
  local field_counter = renumber_config.startNumber or 1
  local enum_counter = 0
  local increment = renumber_config.increment or 1
  local skip_internal = renumber_config.skipInternalRange ~= false -- Default true

  for _, line in ipairs(lines) do
    local new_line = line

    -- Track context
    if line:match('^%s*message%s+') then
      in_message = true
      in_enum = false
      field_counter = renumber_config.startNumber or 1
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
      local before, old_num, after = line:match('(.-)=%s*(%d+)%s*(;.*)$')

      if before and after and not line:match('^%s*//') then -- Skip comments
        local old_number = tonumber(old_num)

        -- Check if this is a reserved number - preserve it
        if renumber_config.preserveReserved and reserved[old_number] then
          -- Keep the old number and don't increment counter
          new_line = line
        else
          -- Assign new number, skipping reserved if configured
          while renumber_config.preserveReserved and reserved[field_counter] do
            field_counter = get_next_field_number(field_counter, increment, skip_internal)
          end

          new_line = string.format('%s= %d%s', before, field_counter, after)
          field_counter = get_next_field_number(field_counter, increment, skip_internal)
        end
      end
    end

    -- Renumber enum values
    if renumber_enums and in_enum then
      local before, after = line:match('(.-)=%s*%d+%s*(;.*)$')

      if before and after and not line:match('^%s*//') then -- Skip comments
        new_line = string.format('%s= %d%s', before, enum_counter, after)
        enum_counter = enum_counter + increment
      end
    end

    table.insert(modified_lines, new_line)
  end

  -- Apply changes
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, modified_lines)
  require('nvim-protobuf.utils').notify('Renumbering complete', vim.log.levels.INFO)
end

return M
