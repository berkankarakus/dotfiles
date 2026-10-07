local original_guicursor = vim.o.guicursor
local buffer = vim.api.nvim_get_current_buf()

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %q, got %q)", message, expected, actual))
end

vim.bo.filetype = "NvimTree"
vim.api.nvim_exec_autocmds("FileType", { buffer = buffer, modeline = false })
assert(vim.o.guicursor:find("n%-v%-c:ver1%-CursorLine"), "tree buffer should use a line cursor")
assert(vim.wo.cursorline, "tree buffer should highlight the selected row")
assert_equal("", vim.wo.colorcolumn, "tree buffer should hide the color column")
assert(vim.wo.winhighlight:find("Cursor:CursorLine", 1, true), "tree buffer should display its cursor as the selected row")

vim.api.nvim_exec_autocmds("BufLeave", { buffer = buffer })
assert_equal(original_guicursor, vim.o.guicursor, "leaving the tree should restore the normal cursor")

print("ui_spec: ok")
vim.cmd("qa!")
