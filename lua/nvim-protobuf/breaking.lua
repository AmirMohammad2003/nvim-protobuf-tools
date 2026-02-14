-- Breaking change detection for nvim-protobuf
-- Compares current proto schema against a git reference
local M = {}

-- Simple proto schema parser
local function parse_schema(content)
  local schema = {
    messages = {},
    enums = {},
  }

  -- Parse messages and their fields
  -- Format: message MessageName { ... }
  for msg_def in content:gmatch('message%s+([%w_]+)%s*{([^}]+)}') do
    local msg_name = msg_def:match('([%w_]+)')
    local msg_body = msg_def:match('%s*{([^}]+)}')

    if msg_name and msg_body then
      schema.messages[msg_name] = parse_message_fields(msg_body)
    end
  end

  -- Parse enums
  for enum_def in content:gmatch('enum%s+([%w_]+)%s*{([^}]+)}') do
    local enum_name = enum_def:match('([%w_]+)')
    local enum_body = enum_def:match('%s*{([^}]+)}')

    if enum_name and enum_body then
      schema.enums[enum_name] = parse_enum_values(enum_body)
    end
  end

  return schema
end

-- Parse message fields
function parse_message_fields(msg_body)
  local fields = {}

  -- Parse field lines: type name = number;
  for line in msg_body:gmatch('[^\n]+') do
    local field_type, field_name, field_num = line:match('([%w_.]+)%s+([%w_]+)%s*=%s*(%d+)')

    if field_type and field_name and field_num then
      table.insert(fields, {
        type = field_type,
        name = field_name,
        number = tonumber(field_num),
      })
    end
  end

  return fields
end

-- Parse enum values
function parse_enum_values(enum_body)
  local values = {}

  for line in enum_body:gmatch('[^\n]+') do
    local value_name, value_num = line:match('([%w_]+)%s*=%s*(%d+)')

    if value_name and value_num then
      table.insert(values, {
        name = value_name,
        number = tonumber(value_num),
      })
    end
  end

  return values
end

-- Compare two schemas and detect breaking changes
local function compare_schemas(old_schema, new_schema)
  local breaking_changes = {}

  -- Check for removed messages
  for msg_name, _ in pairs(old_schema.messages) do
    if not new_schema.messages[msg_name] then
      table.insert(breaking_changes, {
        type = 'removed_message',
        message = string.format('Message "%s" was removed', msg_name),
      })
    end
  end

  -- Check for field changes in existing messages
  for msg_name, old_fields in pairs(old_schema.messages) do
    local new_fields = new_schema.messages[msg_name]

    if new_fields then
      -- Build map of field numbers to fields
      local new_fields_map = {}
      for _, field in ipairs(new_fields) do
        new_fields_map[field.number] = field
      end

      -- Check each old field
      for _, old_field in ipairs(old_fields) do
        local new_field = new_fields_map[old_field.number]

        if not new_field then
          table.insert(breaking_changes, {
            type = 'removed_field',
            message = string.format(
              'Field %s.%s (number %d) was removed',
              msg_name,
              old_field.name,
              old_field.number
            ),
          })
        elseif new_field.type ~= old_field.type then
          table.insert(breaking_changes, {
            type = 'changed_field_type',
            message = string.format(
              'Field %s.%s changed type from %s to %s',
              msg_name,
              old_field.name,
              old_field.type,
              new_field.type
            ),
          })
        end
      end
    end
  end

  -- Check for removed enums
  for enum_name, _ in pairs(old_schema.enums) do
    if not new_schema.enums[enum_name] then
      table.insert(breaking_changes, {
        type = 'removed_enum',
        message = string.format('Enum "%s" was removed', enum_name),
      })
    end
  end

  return breaking_changes
end

-- Format breaking changes as diagnostics
local function format_breaking_changes(breaking_changes, file_path)
  local diagnostics = {}

  for _, change in ipairs(breaking_changes) do
    table.insert(diagnostics, {
      filename = file_path,
      lnum = 0,
      col = 0,
      severity = vim.diagnostic.severity.ERROR,
      message = change.message,
      source = 'breaking-changes',
    })
  end

  return diagnostics
end

-- Check for breaking changes against a git reference
function M.check(git_ref)
  local utils = require('nvim-protobuf.utils')
  local config = require('nvim-protobuf.config').get()

  if not config.breaking.enabled then
    utils.notify('Breaking change detection is disabled', vim.log.levels.WARN)
    return
  end

  git_ref = git_ref or config.breaking.againstGitRef

  local file_path = vim.api.nvim_buf_get_name(0)

  if file_path == '' then
    utils.notify('No file to check', vim.log.levels.ERROR)
    return
  end

  -- Get file content from git ref
  local old_content = utils.git_show(git_ref, file_path)

  if not old_content then
    utils.notify('Could not retrieve file from git ref: ' .. git_ref, vim.log.levels.ERROR)
    return
  end

  -- Get current content
  local current_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')

  -- Parse both versions
  local old_schema = parse_schema(old_content)
  local new_schema = parse_schema(current_content)

  -- Compare schemas
  local breaking_changes = compare_schemas(old_schema, new_schema)

  if #breaking_changes == 0 then
    utils.notify('No breaking changes detected', vim.log.levels.INFO)
    require('nvim-protobuf.diagnostics').clear_all_for_source('breaking')
  else
    -- Show breaking changes as diagnostics
    local diagnostics = format_breaking_changes(breaking_changes, file_path)
    require('nvim-protobuf.diagnostics').set(diagnostics, 'breaking')
    utils.notify(string.format('Found %d breaking change(s)', #breaking_changes), vim.log.levels.WARN)
  end
end

return M
