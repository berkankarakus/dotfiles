local plugins = require("lazy.core.config").plugins

local function assert_true(value, message)
  if not value then error(message, 0) end
end

assert_true(not plugins["nvim-dap"]._.loaded, "DAP should begin unloaded")

local file = vim.fn.tempname() .. ".cs"
vim.fn.writefile({ "class Program {}" }, file)
vim.cmd.edit(vim.fn.fnameescape(file))
vim.wait(100, function()
  return plugins["nvim-dap"]._.loaded ~= nil
end)

assert_true(plugins["nvim-dap"]._.loaded, "opening a C# file should load DAP for persistent breakpoints")

vim.fn.delete(file)
print("lazy_csharp_debug_spec: ok")
