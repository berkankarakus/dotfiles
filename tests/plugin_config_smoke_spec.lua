local plugins = require("lazy.core.config").plugins
local names = vim.tbl_keys(plugins)
table.sort(names)
assert(plugins["virt-column.nvim"].opts.virtcolumn == "120", "virtual guide should be at column 120")

local errors = {}
local original_notify = vim.notify
vim.notify = function(message, level, options)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
  end
  return original_notify(message, level, options)
end

local ok, load_error = pcall(function()
  require("lazy").load({ plugins = names })
end)
vim.notify = original_notify

assert(ok, "loading all plugin configs failed: " .. tostring(load_error))
assert(#errors == 0, "plugin config reported errors:\n" .. table.concat(errors, "\n"))

local unloaded = {}
for _, name in ipairs(names) do
  if not plugins[name]._.loaded then unloaded[#unloaded + 1] = name end
end
assert(#unloaded == 0, "plugins did not load: " .. table.concat(unloaded, ", "))

for _, filetype in ipairs({ "cs", "sql" }) do
  vim.bo.filetype = filetype
  vim.api.nvim_exec_autocmds("FileType", { buffer = 0, modeline = false })
end

for _, item in ipairs({
  { "ab", "x" }, { "if", "o" }, { "]f", "n" }, { "[f", "n" }, { "]a", "n" }, { "[a", "n" },
  { " ff", "n" }, { " fg", "n" }, { " tt", "n" }, { " tw", "n" },
  { " rr", "n" }, { "<C-\\>", "t" }, { "<F5>", "n" }, { "zR", "n" },
}) do
  local mapping = vim.fn.maparg(item[1], item[2], false, true)
  assert(mapping and mapping.lhs and mapping.lhs ~= "", "missing configured mapping " .. item[1])
end

-- Mason only ever installed an x64 netcoredbg that Apple Silicon cannot run: the debugger adapter uses
-- the arm64 binary shipped by netcoredbg-macOS-arm64.nvim, so Mason must stay out of the config.
assert(plugins["mason.nvim"] == nil and plugins["mason-nvim-dap.nvim"] == nil, "Mason is not used and must not come back")
local coreclr = require("dap").adapters.coreclr
assert(coreclr.command:find("netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg", 1, true),
  "the coreclr adapter should use the arm64 binary: " .. tostring(coreclr.command))

-- Formatting is explicit (<leader>cf, ds); saving must never format implicitly.
local has_group, save_hooks = pcall(vim.api.nvim_get_autocmds, { event = "BufWritePre", group = "Conform" })
assert(not has_group or #save_hooks == 0, "conform must not register a format-on-save autocmd")
local conform_options = plugins["conform.nvim"].opts
assert(conform_options.format_on_save == nil and conform_options.format_after_save == nil,
  "conform options must not enable format on save")

assert(#errors == 0, "plugin event config reported errors:\n" .. table.concat(errors, "\n"))
print(string.format("plugin_config_smoke_spec: %d plugin configs loaded", #names))
vim.cmd("qa!")
