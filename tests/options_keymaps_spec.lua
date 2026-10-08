local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %q, got %q)", message, expected, actual))
end

assert_equal(false, vim.o.wrap, "long lines should not wrap")
assert_equal(true, vim.o.number, "absolute line numbers should be enabled")
assert_equal(true, vim.o.relativenumber, "relative line numbers should be enabled")
assert_equal(4, vim.o.shiftwidth, "indent width should be four")
assert_equal("120", vim.o.colorcolumn, "vertical guide should be at column 120")
assert_equal("forth", vim.filetype.match({ filename = "program.fs" }), ".fs should be detected as Forth")

local function callback(mode, key)
  local mapping = vim.fn.maparg(key, mode, false, true)
  assert(mapping and mapping.callback, "missing callback mapping " .. key)
  return mapping.callback
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "someValueOther", "  alpha, beta", "" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
callback("n", "<M-c>")()
assert_equal(4, vim.api.nvim_win_get_cursor(0)[2], "Option-c should move to the next capital")
vim.api.nvim_win_set_cursor(0, { 1, 5 })
callback("n", "<M-C>")()
assert_equal(4, vim.api.nvim_win_get_cursor(0)[2], "Option-C should move to the previous capital")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
callback("n", "<M-d>")()
assert_equal("ValueOther", vim.api.nvim_get_current_line(), "Option-d should delete up to the next capital")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
callback("i", "<M-f>")()
assert_equal(2, vim.api.nvim_win_get_cursor(0)[2], "Option-f should skip leading whitespace to the next word")
callback("i", "<M-f>")()
assert_equal(7, vim.api.nvim_win_get_cursor(0)[2], "Option-f should move to the end of the current word")
callback("i", "<M-f>")()
callback("i", "<M-f>")()
assert_equal(9, vim.api.nvim_win_get_cursor(0)[2], "Option-f should advance through punctuation and whitespace")

local home = callback("i", "<Home>")
vim.api.nvim_win_set_cursor(0, { 2, 0 })
assert_equal("<C-o>^", home(), "Home should go to first nonblank when not already there")
vim.api.nvim_win_set_cursor(0, { 2, 2 })
assert_equal("<C-o>0", home(), "Home should go to column zero when already at first nonblank")
assert_equal("<C-o>$", callback("i", "<End>")(), "End should move to end of line")

vim.bo.filetype = "cs"
assert(vim.bo.formatoptions:find("r", 1, true), "C# should continue block comments")
assert(not vim.bo.formatoptions:find("o", 1, true), "C# should not continue comments on new lines")
assert(not vim.bo.comments:find(",://", 1, true), "C# line comments should not auto-continue")

vim.cmd("qa!")
