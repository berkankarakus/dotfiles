local ui = require("neo.ui")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

-- Replace the timer and the clearing so the logic can be driven deterministically.
local scheduled, cleared = {}, 0
ui.defer = function(callback, delay) scheduled[#scheduled + 1] = { callback = callback, delay = delay } end
ui.clear_message = function() cleared = cleared + 1 end

local function reset()
  scheduled, cleared = {}, 0
  vim.v.errmsg = ""
end

-- 1. A quiet command is cleared after the delay.
reset()
ui.schedule_message_clear()
assert_equal(1, #scheduled, "one clear should be scheduled")
assert_equal(3000, scheduled[1].delay, "the clear should wait three seconds")
assert_equal(0, cleared, "nothing is cleared before the delay passes")
scheduled[1].callback()
assert_equal(1, cleared, "the message should be cleared once the delay passed")

-- 2. An error raised by the command is kept on screen.
reset()
ui.schedule_message_clear()
vim.v.errmsg = "E37: No write since last change"
scheduled[1].callback()
assert_equal(0, cleared, "a new error message must not be cleared")

-- 3. An error from an earlier command does not block clearing a later quiet one.
reset()
vim.v.errmsg = "E486: old error"
ui.schedule_message_clear()
scheduled[1].callback()
assert_equal(1, cleared, "a stale errmsg should not stop the clear")

-- 4. A newer command takes over; the stale timer must not clear its output.
reset()
ui.schedule_message_clear()
ui.schedule_message_clear()
scheduled[1].callback()
assert_equal(0, cleared, "an outdated timer should do nothing")
scheduled[2].callback()
assert_equal(1, cleared, "the latest timer should clear")

-- 5. Leaving normal mode (e.g. the user started typing) cancels the clear.
reset()
ui.schedule_message_clear()
local original_get_mode = vim.api.nvim_get_mode
vim.api.nvim_get_mode = function() return { mode = "i", blocking = false } end
scheduled[1].callback()
vim.api.nvim_get_mode = original_get_mode
assert_equal(0, cleared, "the message should stay while not in normal mode")

-- 6. Wiring: a real Ex command schedules a clear; aborted commands and searches do not.
reset()
vim.api.nvim_feedkeys(vim.keycode(":let g:cmdline_clear_probe = 1<CR>"), "x", false)
assert_equal(1, #scheduled, "an executed Ex command should schedule a clear")

reset()
-- "t" marks the keys as typed; otherwise <Esc> would execute the command line instead of aborting.
vim.api.nvim_feedkeys(vim.keycode(":let g:cmdline_clear_probe = 2<Esc>"), "xt", false)
assert_equal(0, #scheduled, "an aborted command line should not schedule a clear")

reset()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "needle" })
vim.api.nvim_feedkeys(vim.keycode("/needle<CR>"), "x", false)
assert_equal(0, #scheduled, "searches should not schedule a clear")

-- 7. setup is idempotent.
local function count() return #vim.api.nvim_get_autocmds({ group = "ClearCommandLine" }) end
local before = count()
ui.setup()
ui.setup()
assert_equal(before, count(), "setup should not stack duplicate autocmds")
assert(before > 0, "the CmdlineLeave autocmd should be registered")

print("cmdline_clear_spec: ok")
vim.cmd("qa!")
