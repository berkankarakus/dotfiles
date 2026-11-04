-- Tree-sitter parsers and textobjects (the motions themselves live in neo.textobjects).
return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      local mssql_parser = {
        install_info = {
          url = "https://github.com/meloncholic/tree-sitter-mssql",
          revision = "64682111232f63434605a238ef8e4c3112b699d0",
          queries = "queries",
        },
      }
      local parser_group = vim.api.nvim_create_augroup("NeoMssqlParser", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = parser_group,
        pattern = "TSUpdate",
        callback = function()
          require("nvim-treesitter.parsers").mssql = mssql_parser
        end,
      })
      treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
      vim.treesitter.language.register("mssql", "sql")
      treesitter.install({ "c_sharp", "mssql", "json" })
      vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime")
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "cs", "c_sharp", "sql", "json" },
    config = function() require("neo.textobjects").setup() end,
  },
}
