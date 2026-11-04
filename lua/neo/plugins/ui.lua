-- Theme, status line, key hints and diagnostics panel.
return {
  { "folke/tokyonight.nvim", priority = 1000, opts = { style = "moon" } },
  {
    "lukas-reineke/virt-column.nvim",
    opts = {
      char = "┊",
      highlight = "VirtColumn",
      -- Reuse the existing `colorcolumn=120` option instead of defining it twice.
      virtcolumn = "",
      exclude = { filetypes = { "NvimTree" } },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "tokyonight",
        globalstatus = true,
        icons_enabled = false,
        section_separators = "",
        component_separators = " | ",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {},
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  { "nvim-tree/nvim-web-devicons" },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 350,
      icons = { mappings = false },
      spec = {
        { "<leader>f", group = "Find" },
        { "<leader>d", group = "Debug" },
        { "<leader>c", group = "Code" },
        { "<leader>r", group = "Refactor / Run" },
        { "<leader>t", group = "Terminal / Test" },
      },
    },
  },
  {
    "folke/trouble.nvim",
    opts = { focus = true },
    keys = {
      { "<leader>x", "<CMD>Trouble diagnostics toggle<CR>", desc = "Diagnostics panel" },
    },
  },
}
