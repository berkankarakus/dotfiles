local M = {}

function M.setup()
  -- C#-oriented Neovim configuration. Leader stays in the Vim tradition: Space.
  vim.g.mapleader = " "
  -- <C-l> (the usual redraw key) is window navigation here, so this also clears a lingering message.
  vim.keymap.set("n", "<leader><leader>", "<cmd>nohlsearch<Bar>echo ''<CR>", {
    silent = true,
    desc = "Clear search highlight and message",
  })
  vim.g.maplocalleader = " "

  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.wrap = false
  vim.opt.mouse = "a"
  vim.opt.clipboard = "unnamedplus"
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.signcolumn = "yes"
  vim.opt.updatetime = 250
  vim.opt.timeoutlen = 400
  vim.opt.shortmess:append("W")
  vim.opt.splitright = true
  vim.opt.splitbelow = true
  vim.opt.undofile = true
  vim.opt.expandtab = true
  vim.opt.shiftwidth = 4
  vim.opt.tabstop = 4
  vim.opt.list = true
  vim.opt.listchars = { space = "·", multispace = "·", tab = "→ " }
  vim.opt.colorcolumn = "120"
  vim.opt.whichwrap:append("[")
  vim.opt.whichwrap:append("]")
  vim.opt.whichwrap:append("<")
  vim.opt.whichwrap:append(">")
  vim.opt.whichwrap:append("h")
  vim.opt.whichwrap:append("l")

  -- Gforth commonly uses .fs, which Neovim otherwise detects as F#.
  vim.filetype.add({
    extension = {
      fs = "forth",
      gf = "forth",
      gforth = "forth",
    },
  })
end

return M
