-- Shared helpers for the manual Roslyn checks. Output goes to $PROBE_OUT.
local M = {}

function M.log(...)
  local file = io.open(vim.env.PROBE_OUT, "a")
  file:write(table.concat(vim.tbl_map(tostring, { ... }), " "), "\n")
  file:close()
end

-- Opens Program.cs, waits for Roslyn to attach and load the project, and returns
-- the client, the buffer and the (0-based) line of the "// PROBES" marker.
function M.open()
  vim.cmd("edit Program.cs")
  local buf = vim.api.nvim_get_current_buf()
  vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "roslyn" }) > 0 end, 200)
  local client = assert(vim.lsp.get_clients({ bufnr = buf, name = "roslyn" })[1], "roslyn did not attach")
  vim.wait(10000, function() return false end, 200)
  local marker
  for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find("PROBES") then marker = index - 1 end
  end
  return client, buf, assert(marker, "missing PROBES marker")
end

return M
