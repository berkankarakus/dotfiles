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

-- `:q` must report why it did not quit instead of silently doing nothing.
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved scratch text" })
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level) notifications[#notifications + 1] = { message = message, level = level } end
local original_getcmdtype, original_getcmdline = vim.fn.getcmdtype, vim.fn.getcmdline
vim.fn.getcmdtype = function() return ":" end
vim.fn.getcmdline = function() return "q" end
callback("c", "<CR>")()
vim.wait(200, function() return #notifications > 0 end)
vim.fn.getcmdtype, vim.fn.getcmdline = original_getcmdtype, original_getcmdline
vim.notify = original_notify
assert_equal(1, #notifications, "a failed save-all should produce one notification")
assert_equal(vim.log.levels.ERROR, notifications[1].level, "the notification should be an error")
assert(notifications[1].message:find("E141", 1, true), "the notification should name the save error: " .. notifications[1].message)
assert_equal("unsaved scratch text", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "the buffer should still be open")

vim.cmd("qa!")
