-- Neovim diagnostic integration for nvim-protobuf
-- Manages diagnostics from protoc, linters, and breaking change detection
local M = {}

-- Create namespaces for different diagnostic sources
local ns_protoc = vim.api.nvim_create_namespace('nvim-protobuf-protoc')
local ns_linter = vim.api.nvim_create_namespace('nvim-protobuf-linter')
local ns_breaking = vim.api.nvim_create_namespace('nvim-protobuf-breaking')

local namespaces = {
  protoc = ns_protoc,
  linter = ns_linter,
  breaking = ns_breaking,
}

-- Set diagnostics for a specific source
-- @param diagnostics table: Array of diagnostic entries
-- @param source string: Source name ('protoc', 'linter', 'breaking')
function M.set(diagnostics, source)
  source = source or 'protoc'
  local ns = namespaces[source] or ns_protoc

  if not diagnostics or #diagnostics == 0 then
    return
  end

  -- Group diagnostics by buffer
  local by_buffer = {}

  for _, diag in ipairs(diagnostics) do
    -- Get or load buffer for this file
    local bufnr = vim.fn.bufnr(diag.filename)

    if bufnr == -1 then
      -- Buffer not loaded, load it
      bufnr = vim.fn.bufadd(diag.filename)
    end

    by_buffer[bufnr] = by_buffer[bufnr] or {}
    table.insert(by_buffer[bufnr], {
      lnum = diag.lnum,
      col = diag.col,
      severity = diag.severity,
      message = diag.message,
      source = diag.source or source,
    })
  end

  -- Set diagnostics for each buffer
  for bufnr, buf_diagnostics in pairs(by_buffer) do
    vim.diagnostic.set(ns, bufnr, buf_diagnostics)
  end
end

-- Clear diagnostics for a specific source in current buffer
-- @param source string: Source name ('protoc', 'linter', 'breaking')
function M.clear(source)
  source = source or 'protoc'
  local ns = namespaces[source] or ns_protoc

  local bufnr = vim.api.nvim_get_current_buf()
  vim.diagnostic.reset(ns, bufnr)
end

-- Clear all diagnostics from all sources
function M.clear_all()
  for _, ns in pairs(namespaces) do
    vim.diagnostic.reset(ns)
  end
end

-- Clear diagnostics for a specific source across all buffers
-- @param source string: Source name ('protoc', 'linter', 'breaking')
function M.clear_all_for_source(source)
  source = source or 'protoc'
  local ns = namespaces[source] or ns_protoc
  vim.diagnostic.reset(ns)
end

return M
