local plugins = require("lazy.core.config").plugins

local function assert_true(value, message)
  if not value then error(message, 0) end
end

for _, name in ipairs({ "nvim-cmp", "nvim-autopairs" }) do
  assert_true(not plugins[name]._.loaded, name .. " should begin unloaded")
end

vim.api.nvim_exec_autocmds("InsertEnter", {})
vim.wait(100, function()
  return plugins["nvim-cmp"]._.loaded and plugins["nvim-autopairs"]._.loaded
end)

for _, name in ipairs({ "nvim-cmp", "nvim-autopairs" }) do
  assert_true(plugins[name]._.loaded, name .. " should load on InsertEnter")
end

print("lazy_completion_spec: ok")
