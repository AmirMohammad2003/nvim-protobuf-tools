-- Async job execution wrapper for nvim-protobuf
local M = {}

-- Run a command asynchronously
-- opts = {
--   cmd = { 'protoc', '--version' },  -- Command as array
--   cwd = '/path/to/cwd',             -- Optional working directory
--   on_exit = function(code, stdout, stderr) end  -- Callback when done
-- }
function M.run(opts)
  if not opts.cmd or type(opts.cmd) ~= 'table' or #opts.cmd == 0 then
    error('job.run requires opts.cmd as a non-empty array')
  end

  local cmd = opts.cmd
  local cwd = opts.cwd
  local on_exit = opts.on_exit or function() end

  -- Build system opts
  local system_opts = {
    text = true,
  }

  if cwd then
    system_opts.cwd = cwd
  end

  -- Execute command asynchronously
  vim.system(cmd, system_opts, function(obj)
    -- Schedule callback to run in main event loop
    vim.schedule(function()
      on_exit(obj.code, obj.stdout or '', obj.stderr or '')
    end)
  end)
end

-- Run command synchronously and return result
-- Returns: code, stdout, stderr
function M.run_sync(opts)
  if not opts.cmd or type(opts.cmd) ~= 'table' or #opts.cmd == 0 then
    error('job.run_sync requires opts.cmd as a non-empty array')
  end

  local cmd = opts.cmd
  local cwd = opts.cwd

  -- Build system opts
  local system_opts = {
    text = true,
  }

  if cwd then
    system_opts.cwd = cwd
  end

  -- Execute command synchronously
  local obj = vim.system(cmd, system_opts):wait()

  return obj.code, obj.stdout or '', obj.stderr or ''
end

return M
