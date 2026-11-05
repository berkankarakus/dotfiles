-- Roslyn and Elm language server setup plus the LSP keymaps. Called from the roslyn.nvim spec
-- before roslyn.nvim's own setup, as nvim-lspconfig's config used to run.
local M = {}

function M.setup()
  require("neo.lsp.servers").setup()
  require("neo.lsp.keymaps").setup()
end

return M
