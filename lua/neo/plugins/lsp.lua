-- Language servers (Roslyn, Elm; see neo.lsp), LSP keymaps and formatting.
return {
  {
    "seblyng/roslyn.nvim",
    config = function()
      require("neo.lsp").setup()
      require("roslyn").setup({})
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      -- C# formatting is delegated to Roslyn so project .editorconfig rules apply.
      -- There is deliberately no format_on_save: formatting happens on <leader>cf and after `ds`.
      -- jq has no range mode; conform then formats the whole document and applies only the changes
      -- that overlap the selection (and jq refuses invalid JSON, which leaves the buffer untouched).
      formatters_by_ft = { elm = { "elm_format" }, json = { "jq" } },
    },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "x" },
        desc = "Format buffer or selection",
      },
    },
  },
}
