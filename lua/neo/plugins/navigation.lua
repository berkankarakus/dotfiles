-- File explorers and fuzzy finders.
return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      columns = { "permissions", "size", "mtime" },
      view_options = { show_hidden = true },
    },
    keys = {
      { "<leader>o", "<CMD>Oil<CR>", desc = "Open file explorer" },
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view = { width = 34 },
      renderer = {
        indent_markers = { enable = true },
        icons = { show = { file = true, folder = true, folder_arrow = false, git = false } },
      },
      filters = {
        dotfiles = true,
        custom = { "^bin$", "^obj$", "^%.DS_Store$" },
      },
      update_focused_file = { enable = true, update_root = false },
      actions = { remove_file = { close_window = false } },
      git = { enable = false },
      on_attach = function(bufnr)
        local api = require("nvim-tree.api")
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set("n", "<Right>", api.node.open.edit, {
          buffer = bufnr,
          desc = "Open selected file or folder",
        })
        vim.keymap.set("n", "<Left>", api.node.navigate.parent_close, {
          buffer = bufnr,
          desc = "Close folder or go to parent",
        })
      end,
    },
    keys = {
      { "<leader>n", "<CMD>NvimTreeToggle<CR>", desc = "Toggle file tree" },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
      { "<leader>fg", desc = "Search project text" },
      { "<leader>fG", desc = "Fuzzy search project text" },
      { "<leader>fb", desc = "Find buffers" },
      { "<leader>fs", desc = "Search document symbols" },
      { "<leader>fS", desc = "Search workspace symbols" },
      { "<leader>fh", desc = "Search help" },
    },
    config = function()
      local telescope = require("telescope")
      local vimgrep_arguments = vim.deepcopy(require("telescope.config").values.vimgrep_arguments)
      table.insert(vimgrep_arguments, "--ignore-case")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          sorting_strategy = "ascending",
          disable_devicons = true,
          vimgrep_arguments = vimgrep_arguments,
        },
      })
      pcall(telescope.load_extension, "fzf")
      local builtin = require("telescope.builtin")
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local make_entry = require("telescope.make_entry")
      local telescope_config = require("telescope.config").values

      local function fuzzy_grep()
        local opts = {}
        opts.entry_maker = make_entry.gen_from_vimgrep(opts)
        local source_globs = {
          "*.cs",
          "*.pas",
          "*.csproj",
          "*.sln",
          "*.slnx",
          "*.props",
          "*.targets",
          "*.json",
          "*.xml",
          "*.config",
          ".editorconfig",
        }

        local function fuzzy_pattern(prompt)
          local characters = {}
          for _, character in ipairs(vim.fn.split(prompt, [[\zs]])) do
            if not character:match("%s") then
              table.insert(characters, vim.fn.escape(character, [[\.^$|?*+()[]{}]]))
            end
          end
          return table.concat(characters, ".*")
        end

        pickers
          .new(opts, {
            prompt_title = "Fuzzy Grep",
            finder = finders.new_job(function(prompt)
              if not prompt or prompt == "" then
                return nil
              end

              local args = { "rg", "--vimgrep", "--ignore-case" }
              for _, glob in ipairs(source_globs) do
                table.insert(args, "--glob=" .. glob)
              end
              table.insert(args, "--")
              table.insert(args, fuzzy_pattern(prompt))
              return args
            end, opts.entry_maker, nil, opts.cwd),
            previewer = telescope_config.grep_previewer(opts),
            sorter = telescope_config.generic_sorter(opts),
          })
          :find()
      end

      vim.keymap.set("n", "<leader>ff", function()
        require("telescope").extensions.frecency.frecency({ workspace = "CWD" })
      end, { desc = "Find project files by frecency" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Search project text" })
      vim.keymap.set("n", "<leader>fG", fuzzy_grep, { desc = "Fuzzy search project text" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Search document symbols" })
      vim.keymap.set("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Search workspace symbols" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Search help" })
    end,
  },
  {
    "nvim-telescope/telescope-frecency.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>ff", desc = "Find project files by frecency" },
    },
    config = function()
      require("telescope").load_extension("frecency")
    end,
  },
}
