-- Missing files must be dropped from the frecency database without asking: the question is asked from
-- inside init(), which only waits 5 s, so a slow answer ends in "init() never returns during the time".
local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

require("lazy").load({ plugins = { "telescope-frecency.nvim" } })
assert_equal(false, require("frecency.config").get().db_safe_mode, "db_safe_mode should be off")

-- Behaviour: visit more files than db_validate_threshold, delete them, then validate.
local prompts, notes = {}, {}
vim.ui.select = function(_, opts) prompts[#prompts + 1] = opts.prompt end
local original_notify = vim.notify
vim.notify = function(message) notes[#notes + 1] = tostring(message) end

local dir = vim.fn.tempname() .. "-frecency"
vim.fn.mkdir(dir, "p")
for index = 1, 12 do
  local path = string.format("%s/f%02d.txt", dir, index)
  vim.fn.writefile({ "x" }, path)
  vim.cmd("silent edit " .. vim.fn.fnameescape(path))
  vim.wait(100)
end
vim.wait(1000)
vim.cmd("silent enew")
vim.fn.delete(dir, "rf")

-- :FrecencyValidate! runs the same validation as the picker's cleanup (forced past the threshold).
vim.cmd("FrecencyValidate!")
vim.wait(5000, function()
  for _, note in ipairs(notes) do
    if note:find("missing entries", 1, true) then return true end
  end
  return false
end, 50)
vim.notify = original_notify

assert_equal(0, #prompts, "no confirmation prompt should be shown")
local removed
for _, note in ipairs(notes) do removed = removed or note:match("removed (%d+) missing entries") end
-- db_validate_threshold is 10, so removing more than that proves the prompt would have been asked.
assert(removed and tonumber(removed) >= 10, "the missing entries should be removed, got: " .. table.concat(notes, " | "))

print("frecency_cleanup_spec: ok")
vim.cmd("qa!")
