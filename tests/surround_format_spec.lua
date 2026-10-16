local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %q, got %q)", message, vim.inspect(expected), vim.inspect(actual)))
end

require("lazy").load({ plugins = { "mini.surround", "conform.nvim" } })

local conform = require("conform")
local calls = {}
local original = conform.format
conform.format = function(opts)
  table.insert(calls, opts)
  return true
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "before", "if (x) {", "  a();", "  b();", "}", "after" })
vim.api.nvim_win_set_cursor(0, { 3, 2 })
vim.api.nvim_feedkeys(vim.keycode("ds}"), "x", false)

assert_equal(1, #calls, "ds should trigger exactly one format call")
local range = calls[1].range
assert_equal(2, range.start[1], "range should start at the first affected line")
assert(range["end"][1] <= 5, "range should not reach unaffected trailing lines")
assert(range["end"][1] >= 3, "range should cover the surrounded lines")
assert_equal("before", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "lines above must stay outside the range")

conform.format = original
vim.print("surround format spec ok")
