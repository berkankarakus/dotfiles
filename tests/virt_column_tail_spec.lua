local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local module = require("neo.virt_column_tail")
local namespace = vim.api.nvim_get_namespaces()["neo-virt-column-tail"]
assert(namespace, "virt-column tail namespace should exist")

local function autocmds()
  return vim.api.nvim_get_autocmds({ group = "NeoVirtColumnTail" })
end

local before = #autocmds()
module.setup()
module.setup()
assert_equal(before, #autocmds(), "virt-column setup should be idempotent")

local seen_events = {}
for _, autocmd in ipairs(autocmds()) do seen_events[autocmd.event] = true end
assert(not seen_events.CursorMoved and not seen_events.CursorMovedI,
  "cursor movement should not trigger a full virt-column refresh")

vim.cmd("enew")
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "short", "short", "short", "short", string.rep("x", 130) })
vim.api.nvim_exec_autocmds("BufEnter", { buffer = 0, modeline = false })
local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
assert_equal(2, #marks, "only short lines in the final three lines should receive a guide")
assert_equal(2, marks[1][2], "the first guide row should be the third line")
assert_equal(3, marks[2][2], "the second guide row should be the fourth line")

print("virt_column_tail_spec: ok")
vim.cmd("qa!")
