local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

-- The plugin reads the terminal and terminal-notifier once, when it loads, so fake both first.
vim.env.TERM_PROGRAM = "ghostty"
local exepath = vim.fn.exepath
vim.fn.exepath = function(name)
  if name == "terminal-notifier" then return "/fake/bin/terminal-notifier" end
  return exepath(name)
end

local jobs, notes = {}, {}
vim.fn.jobstart = function(command, options) jobs[#jobs + 1] = { command = command, options = options } return 1 end
vim.notify = function(message, level, options) notes[#notes + 1] = { message = message, level = level, options = options } end

require("lazy").load({ plugins = { "nvim-dap" } })
local dap = require("dap")
local listener = dap.listeners.after.event_stopped["debug-notification"]
assert(listener, "the breakpoint listener should be registered")

listener(nil, { reason = "breakpoint" })
assert_equal(1, #notes, "a breakpoint should notify inside Neovim")
assert_equal("Breakpoint reached.", notes[1].message, "the in-editor message")
assert_equal("Neovim Debugger", notes[1].options.title, "the in-editor title")
assert_equal(1, #jobs, "a breakpoint should start terminal-notifier")
assert_equal(
  vim.inspect({ "/fake/bin/terminal-notifier", "-title", "Neovim Debugger", "-message", "Breakpoint reached.", "-activate", "com.mitchellh.ghostty" }),
  vim.inspect(jobs[1].command),
  "clicking the notification should activate Ghostty"
)
assert_equal(true, jobs[1].options.detach, "terminal-notifier should outlive the job handle")

listener(nil, { reason = "step" })
listener(nil, { reason = "exception" })
assert_equal(1, #notes, "stops that are not breakpoints should stay silent")
assert_equal(1, #jobs, "stops that are not breakpoints should not start terminal-notifier")

print("debug_notification_spec: ok")
