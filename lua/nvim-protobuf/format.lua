-- Formatting support for nvim-protobuf
-- Supports built-in formatter, clang-format, and buf format
local M = {}

-- Apply basic built-in formatting
local function apply_basic_formatting(lines)
  local formatted = {}
  local indent_level = 0
  local indent_size = 2
  local config = require('nvim-protobuf.config').get()

  local prev_was_empty = false
  local empty_count = 0

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    -- Track empty lines
    if trimmed == '' then
      empty_count = empty_count + 1

      -- Only add empty line if within max limit
      if empty_count <= (config.formatter.maxEmptyLines or 1) then
        table.insert(formatted, '')
      end

      prev_was_empty = true
    else
      empty_count = 0

      -- Decrease indent for closing braces
      if trimmed:match('^}') then
        indent_level = math.max(0, indent_level - 1)
      end

      -- Apply indentation
      table.insert(formatted, string.rep(' ', indent_level * indent_size) .. trimmed)

      -- Increase indent for opening braces
      if trimmed:match('{%s*$') then
        indent_level = indent_level + 1

        -- Insert empty line after opening brace if configured
        if config.formatter.insertEmptyLineBetweenDefinitions and not prev_was_empty then
          -- Will be added before next definition
        end
      end

      prev_was_empty = false
    end
  end

  return formatted
end

-- Format using built-in formatter
local function format_builtin()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local formatted = apply_basic_formatting(lines)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
  require('nvim-protobuf.utils').notify('Formatted with built-in formatter', vim.log.levels.INFO)
end

-- Format using clang-format
local function format_clang()
  local utils = require('nvim-protobuf.utils')
  local job = require('nvim-protobuf.job')
  local file_path = vim.api.nvim_buf_get_name(0)

  if not utils.command_exists('clang-format') then
    utils.notify('clang-format not found', vim.log.levels.ERROR)
    return
  end

  job.run({
    cmd = { 'clang-format', '-i', file_path },
    on_exit = function(code, stdout, stderr)
      if code == 0 then
        -- Reload buffer
        vim.cmd('checktime')
        utils.notify('Formatted with clang-format', vim.log.levels.INFO)
      else
        utils.notify('Formatting failed: ' .. stderr, vim.log.levels.ERROR)
      end
    end,
  })
end

-- Format using buf
local function format_buf()
  local utils = require('nvim-protobuf.utils')
  local job = require('nvim-protobuf.job')
  local file_path = vim.api.nvim_buf_get_name(0)

  if not utils.command_exists('buf') then
    utils.notify('buf not found', vim.log.levels.ERROR)
    return
  end

  job.run({
    cmd = { 'buf', 'format', file_path, '-w' },
    cwd = utils.find_workspace_root(),
    on_exit = function(code, stdout, stderr)
      if code == 0 then
        -- Reload buffer
        vim.cmd('checktime')
        utils.notify('Formatted with buf', vim.log.levels.INFO)
      else
        utils.notify('Formatting failed: ' .. stderr, vim.log.levels.ERROR)
      end
    end,
  })
end

-- Main format function - dispatches to appropriate formatter
function M.format()
  local config = require('nvim-protobuf.config')
  local formatter_type = config.get_formatter_type()

  if formatter_type == 'none' then
    require('nvim-protobuf.utils').notify('Formatter disabled', vim.log.levels.WARN)
    return
  end

  if formatter_type == 'builtin' then
    format_builtin()
  elseif formatter_type == 'clang-format' then
    format_clang()
  elseif formatter_type == 'buf' then
    format_buf()
  else
    require('nvim-protobuf.utils').notify('Unknown formatter: ' .. formatter_type, vim.log.levels.ERROR)
  end
end

return M
