-- Completion, snippets and bracket pairing.
return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" },
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      local ls = require("luasnip")
      local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node
      local function class_name()
        for line_number = vim.api.nvim_win_get_cursor(0)[1], 1, -1 do
          local name = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]:match("class%s+([%w_]+)")
          if name then return name end
        end
        return "ClassName"
      end
      ls.add_snippets("cs", {
        s("ctor", { t("public "), f(class_name), t("("), i(1), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("prop", { t("public "), i(1, "Type"), t(" "), i(2, "Name"), t(" { get; set; }") }),
        s("propg", {
          t("private "), i(1, "Type"), t(" _"), i(2, "name"), t({ ";", "", "public " }),
          f(function(args) return args[1][1] end, { 1 }), t(" "), i(3, "Name"), t({ "", "{", "    get => _" }),
          f(function(args) return args[1][1] end, { 2 }), t({ ";", "    set => _" }),
          f(function(args) return args[1][1] end, { 2 }), t({ " = value;", "}" }),
        }),
        s("if", { t("if ("), i(1, "condition"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("for", { t("for (int i = 0; i < "), i(1, "count"), t({ "; i++)", "{", "    " }), i(0), t({ "", "}" }) }),
        s("foreach", { t("foreach (var "), i(1, "item"), t(" in "), i(2, "items"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("while", { t("while ("), i(1, "condition"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("dowhile", { t({ "do", "{", "    " }), i(1), t({ "", "} while (" }), i(2, "condition"), t(");"), i(0) }),
        s("?:", { i(1, "condition"), t(" ? "), i(2, "trueValue"), t(" : "), i(3, "falseValue"), i(0) }),
        s("region", { t("#region "), i(1, "Name"), t({ "", "" }), i(0), t({ "", "#endregion" }) }),
        s("comment", { t({ "/*", " * " }), i(1), t({ "", " */", "" }), i(0) }),
        s("psr", { t("private static readonly "), i(0) }),
        s("try", { t({ "try", "{", "    " }), i(1), t({ "", "}", "catch (" }), i(2, "Exception ex"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        require("neo.snippets").switch_expression(ls),
        s("cw", { t("Console.WriteLine("), i(1), t(");") }),
      })
      ls.add_snippets("cs", require("neo.snippets").collection_declarations(ls))
      cmp.setup({
        enabled = function()
          local context = require("cmp.config.context")
          return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
        end,
        snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true, behavior = cmp.ConfirmBehavior.Replace }),
          ["<Esc>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.abort() else fallback() end
          end, { "i", "s" }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if ls.expandable() then ls.expand()
            elseif cmp.visible() then cmp.select_next_item()
            elseif require("neo.csharp").jump_docstring_field() then
            elseif require("neo.snippets").switch_tab() then
            elseif ls.locally_jumpable() then ls.jump(1)
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif ls.locally_jumpable(-1) then ls.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          {
            name = "luasnip",
            entry_filter = function()
              local context = require("cmp.config.context")
              return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
            end,
          },
          { name = "path" },
        }, { { name = "buffer" } }),
      })

    end,
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true,
        disable_filetype = { "TelescopePrompt", "vim" },
      })
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      -- C# call parentheses are handled by neo.call_parens, which places the cursor by arity.
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done({ filetypes = { cs = false } }))
      cmp.event:on("confirm_done", function(event)
        local call_parens = require("neo.call_parens")
        if vim.bo.filetype == "cs" then call_parens.handle(event) else call_parens.handle_new(event) end
      end)
    end,
  },
}
