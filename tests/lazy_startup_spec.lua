local plugins = require("lazy.core.config").plugins

local function assert_true(value, message)
  if not value then error(message, 0) end
end

for _, name in ipairs({ "nvim-dap", "telescope.nvim", "nvim-cmp", "nvim-autopairs", "roslyn.nvim", "nvim-treesitter" }) do
  assert_true(plugins[name], name .. " is missing from the Lazy spec")
  assert_true(not plugins[name]._.loaded, name .. " should not load during startup")
end

for _, key in ipairs({ "<F5>", " fg", " ff", " cf" }) do
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert_true(mapping and mapping.lhs and mapping.lhs ~= "", key .. " should remain mapped")
end

print("lazy_startup_spec: ok")
