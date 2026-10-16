local M = {}

-- Plugin specs live in lua/neo/plugins/<name>.lua; each module returns a list of lazy.nvim specs.
local MODULES = { "ui", "editing", "navigation", "treesitter", "lsp", "completion", "debug" }

function M.setup()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    vim.notify("lazy.nvim is missing. Run the setup command again.", vim.log.levels.ERROR)
    return
  end
  vim.opt.rtp:prepend(lazypath)

  local specs = {}
  for _, name in ipairs(MODULES) do
    specs[#specs + 1] = require("neo.plugins." .. name)
  end
  require("lazy").setup(specs, { checker = { enabled = true }, change_detection = { notify = false } })

  vim.cmd.colorscheme("tokyonight")
  vim.api.nvim_set_hl(0, "VirtColumn", { fg = "#3b4261" })
end

return M
