local function mapping(mode, lhs)
  local result = vim.fn.maparg(lhs, mode, false, true)
  assert(result and result.callback, "missing terminal mapping " .. lhs)
  return result.callback
end

local original_cmd = vim.cmd
local original_chansend = vim.fn.chansend
local sent
vim.cmd = function(command)
  if command == "botright 15split | terminal" then
    original_cmd("botright 15split")
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buffer)
    vim.b[buffer].terminal_job_id = 1234
    return
  elseif command == "startinsert" or command == "stopinsert" then
    return
  end
  return original_cmd(command)
end
vim.fn.chansend = function(job_id, text)
  sent = { job_id = job_id, text = text }
  return #text
end

local function terminal_buffer_visible(buffer)
  for _, window in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(window) == buffer then return true end
  end
  return false
end

mapping("n", " tt")()
local buffer = vim.api.nvim_get_current_buf()
assert(terminal_buffer_visible(buffer), "terminal toggle should create a visible terminal buffer")

mapping("n", " tw")()
assert(sent and sent.job_id == 1234 and sent.text == "dotnet test --watch\n", "test watch should be sent to the terminal")
mapping("n", " rr")()
assert(sent.text == "dotnet test\n", "test run should be sent to the terminal")

mapping("n", " tt")()
assert(not terminal_buffer_visible(buffer), "terminal toggle should hide the visible terminal")
mapping("n", " tt")()
assert(vim.api.nvim_get_current_buf() == buffer, "terminal toggle should reuse its existing buffer")

vim.cmd = original_cmd
vim.fn.chansend = original_chansend
print("terminal_spec: ok")
vim.cmd("qa!")
