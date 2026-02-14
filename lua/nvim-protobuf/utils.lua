-- Utility functions for nvim-protobuf
local M = {}

-- Find workspace root by searching for markers
function M.find_workspace_root()
  -- Markers that indicate a workspace root
  local markers = { '.git', 'buf.yaml', 'buf.work.yaml', '.proto' }

  -- Start from current buffer's directory
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == '' then
    current_file = vim.fn.getcwd()
  end

  local current_dir = vim.fn.fnamemodify(current_file, ':h')

  -- Search upwards until we find a marker or reach root
  while current_dir ~= '/' do
    for _, marker in ipairs(markers) do
      local marker_path = current_dir .. '/' .. marker
      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        return current_dir
      end
    end

    -- Move up one directory
    current_dir = vim.fn.fnamemodify(current_dir, ':h')
  end

  -- Fallback to current working directory
  return vim.fn.getcwd()
end

-- Get file content from a git reference
function M.git_show(ref, file_path)
  -- Make file_path relative to workspace root if it's absolute
  local workspace_root = M.find_workspace_root()
  if vim.startswith(file_path, workspace_root) then
    file_path = file_path:sub(#workspace_root + 2) -- +2 to skip the trailing slash
  end

  local cmd = string.format('git show %s:%s 2>/dev/null', vim.fn.shellescape(ref), vim.fn.shellescape(file_path))
  local handle = io.popen(cmd)

  if not handle then
    return nil
  end

  local content = handle:read('*a')
  local success = handle:close()

  if not success or content == '' then
    return nil
  end

  return content
end

-- Check if a file is a proto file
function M.is_proto_file(file_path)
  if not file_path or file_path == '' then
    return false
  end
  return file_path:match('%.proto$') ~= nil
end

-- Get the relative path from workspace root
function M.get_relative_path(file_path)
  local workspace_root = M.find_workspace_root()
  if vim.startswith(file_path, workspace_root) then
    return file_path:sub(#workspace_root + 2)
  end
  return file_path
end

-- Check if a command exists in PATH
function M.command_exists(cmd)
  local handle = io.popen('command -v ' .. vim.fn.shellescape(cmd) .. ' 2>/dev/null')
  if not handle then
    return false
  end

  local result = handle:read('*a')
  handle:close()

  return result ~= ''
end

-- Notify with plugin prefix
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  vim.notify('[nvim-protobuf] ' .. message, level)
end

-- Escape special characters for pattern matching
function M.escape_pattern(text)
  return text:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
end

return M
