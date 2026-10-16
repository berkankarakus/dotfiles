-- Text editing helpers: surround (with scoped format on delete), word highlights and folds.
return {
  {
    "echasnovski/mini.surround",
    version = false,
    opts = {
      mappings = { delete = "ds" },
      respect_selection_type = true,
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)

      -- Format only the lines touched by `ds`. Dot-repeat and `dsn`/`dsl`
      -- resolve MiniSurround.delete at call time, so wrapping it covers them.
      local delete = MiniSurround.delete
      MiniSurround.delete = function(...)
        local buf = vim.api.nvim_get_current_buf()
        local first, last
        local tracking = true
        vim.api.nvim_buf_attach(buf, false, {
          on_lines = function(_, _, _, firstline, lastline, new_lastline)
            if not tracking then return true end
            if first == nil then
              first, last = firstline, math.max(firstline, new_lastline - 1)
            else
              if last >= lastline then last = last + (new_lastline - lastline) end
              first = math.min(first, firstline)
              last = math.max(last, new_lastline - 1)
            end
          end,
        })
        local result = delete(...)
        tracking = false
        if first then
          last = math.min(last, vim.api.nvim_buf_line_count(buf) - 1)
          local text = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
          pcall(require("conform").format, {
            bufnr = buf,
            range = { start = { first + 1, 0 }, ["end"] = { last + 1, #text } },
            lsp_format = "fallback",
            timeout_ms = 1500,
            quiet = true,
          })
        end
        return result
      end
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      require("illuminate").configure({
        delay = 200,
        filetypes_allowlist = { "sql" },
        filetypes_denylist = {},
        filetype_overrides = {
          sql = { case_insensitive_regex = true },
        },
      })
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    opts = {
      provider_selector = function(_, filetype, buftype)
        if buftype ~= "" then return "" end
        if filetype == "cs" then return { "lsp" } end
        return { "treesitter", "indent" }
      end,
    },
    config = function(_, opts)
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
      require("ufo").setup(opts)
      vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
    end,
  },
}
