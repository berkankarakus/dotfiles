local M = {}

function M.setup()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    vim.notify("lazy.nvim is missing. Run the setup command again.", vim.log.levels.ERROR)
    return
  end
  vim.opt.rtp:prepend(lazypath)

  require("lazy").setup({
    { "folke/tokyonight.nvim", priority = 1000, opts = { style = "moon" } },
    {
      "lukas-reineke/virt-column.nvim",
      opts = { char = "┊", virtcolumn = "80", exclude = { filetypes = { "NvimTree" } } },
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
          { "<leader>b", group = "Breakpoint" },
          { "<leader>d", group = "Debug" },
          { "<leader>c", group = "Code" },
          { "<leader>r", group = "Refactor / Run" },
          { "<leader>t", group = "Terminal / Test" },
          { "<leader>w", group = "Write" },
          { "<leader>R", desc = "Sync plugins" },
        },
      },
    },
    {
      "echasnovski/mini.surround",
      version = false,
      opts = {
        mappings = { delete = "ds" },
        respect_selection_type = true,
      },
    },
    {
      "mg979/vim-visual-multi",
      init = function()
        vim.g.VM_maps = {
          ["Add Cursor Down"] = "<M-j>",
          ["Add Cursor Up"] = "<M-k>",
        }
      end,
    },
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
      "folke/trouble.nvim",
      opts = { focus = true },
      keys = {
        { "<leader>x", "<CMD>Trouble diagnostics toggle<CR>", desc = "Diagnostics panel" },
      },
    },
    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter").setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
        vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime")
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
    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
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
      config = function()
        require("telescope").load_extension("frecency")
      end,
    },
    {
      "williamboman/mason.nvim",
      opts = {},
    },
    {
      "seblyng/roslyn.nvim",
      dependencies = { "neovim/nvim-lspconfig" },
      opts = {},
    },
    {
      "neovim/nvim-lspconfig",
      config = function()
        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
        vim.lsp.config("roslyn", {
          capabilities = capabilities,
          cmd = { vim.fn.expand("~/.dotnet/tools/roslyn-language-server"), "--stdio" },
          settings = {
            ["csharp|background_analysis"] = {
              dotnet_analyzer_diagnostics_scope = "openFiles",
              dotnet_compiler_diagnostics_scope = "openFiles",
            },
            ["csharp|inlay_hints"] = {
              csharp_enable_inlay_hints_for_lambda_parameter_types = true,
              dotnet_enable_inlay_hints_for_parameters = true,
            },
            ["csharp|completion"] = { dotnet_show_completion_items_from_unimported_namespaces = true },
          },
      })
      vim.lsp.enable("roslyn")
      vim.lsp.config("elmls", {
        capabilities = capabilities,
      })
      vim.lsp.enable("elmls")
      vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(event)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
            end
            local client = vim.lsp.get_client_by_id(event.data.client_id)
            if client and vim.bo[event.buf].filetype == "cs" and client.server_capabilities.inlayHintProvider then
              vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
            end
            local code_action = function()
              vim.lsp.buf.code_action()
            end
            local signature_state = {}
            local function show_next_signature()
              local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
              vim.lsp.buf_request(event.buf, "textDocument/signatureHelp", params, function(err, result)
                if err or not result or not result.signatures or #result.signatures == 0 then
                  vim.notify("No signature available here.", vim.log.levels.INFO)
                  return
                end

                local position = vim.api.nvim_win_get_cursor(0)
                local state_key = table.concat({ event.buf, position[1], position[2], #result.signatures }, ":")
                local signature_index
                if signature_state.key == state_key then
                  signature_index = (signature_state.index + 1) % #result.signatures
                else
                  signature_index = result.activeSignature or 0
                end
                signature_state = { key = state_key, index = signature_index }

                vim.lsp.util.open_floating_preview({ result.signatures[signature_index + 1].label }, "cs", {
                  border = "rounded",
                  title = string.format(" Overload %d/%d ", signature_index + 1, #result.signatures),
                  focusable = false,
                  focus_id = "csharp-signature-overload",
                })
              end)
            end
            map("gd", vim.lsp.buf.definition, "Go to definition")
            map("gi", vim.lsp.buf.implementation, "Go to implementation")
            map("gr", vim.lsp.buf.references, "References")
            map("K", vim.lsp.buf.hover, "Documentation")
            map("<leader>s", show_next_signature, "Next overload")
            map("<leader>rn", vim.lsp.buf.rename, "Rename")
            vim.keymap.set({ "n", "x" }, "<leader>ca", code_action, { buffer = event.buf, desc = "Code action" })
            map("<leader>cd", require("neo.csharp").insert_docstring, "Insert C# docstring")
            map("<leader>e", vim.diagnostic.open_float, "Diagnostics")
            map("<leader>y", function()
              local diagnostics = vim.diagnostic.get(event.buf, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
              if #diagnostics == 0 then
                vim.notify("No diagnostics on this line.", vim.log.levels.INFO)
                return
              end
              vim.fn.setreg("+", table.concat(vim.tbl_map(function(diagnostic) return diagnostic.message end, diagnostics), "\n"))
              vim.notify("Diagnostic copied.", vim.log.levels.INFO)
            end, "Copy diagnostic")
            if client and client.server_capabilities.documentHighlightProvider then
              local group = vim.api.nvim_create_augroup("LspDocumentHighlight" .. event.buf, { clear = true })
              vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = group,
                buffer = event.buf,
                callback = vim.lsp.buf.document_highlight,
              })
              vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = group,
                buffer = event.buf,
                callback = vim.lsp.buf.clear_references,
              })
            end
          end,
        })
      end,
    },
    {
      "hrsh7th/nvim-cmp",
      dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" },
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
          s("region", { t("#region "), i(1, "Name"), t({ "", "" }), i(0), t({ "", "#endregion" }) }),
          s("comment", { t({ "/*", " * " }), i(1), t({ "", " */", "" }), i(0) }),
          s("psr", { t("private static readonly "), i(0) }),
          s("try", { t({ "try", "{", "    " }), i(1), t({ "", "}", "catch (" }), i(2, "Exception ex"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
          s("cw", { t("Console.WriteLine("), i(1), t(");") }),
        })
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
      lazy = false,
      dependencies = { "hrsh7th/nvim-cmp" },
      config = function()
        require("nvim-autopairs").setup({
          check_ts = true,
          disable_filetype = { "TelescopePrompt", "vim" },
        })
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        local cmp = require("cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        cmp.event:on("confirm_done", function(event)
          if event.commit_character then return end
          local item = event.entry:get_completion_item()
          if item.label ~= "new" then return end

          local row, column = unpack(vim.api.nvim_win_get_cursor(0))
          local line = vim.api.nvim_get_current_line()
          if line:sub(1, column):match("%f[%w]new$") and line:sub(column + 1, column + 1) ~= "(" then
            vim.api.nvim_buf_set_text(0, row - 1, column, row - 1, column, { "()" })
            vim.api.nvim_win_set_cursor(0, { row, column + 1 })
          end
        end)
      end,
    },
    {
      "stevearc/conform.nvim",
      opts = {
        -- C# formatting is delegated to Roslyn so project .editorconfig rules apply.
        formatters_by_ft = { elm = { "elm_format" } },
        format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
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
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
        { "Cliffback/netcoredbg-macOS-arm64.nvim" },
        { "jay-babu/mason-nvim-dap.nvim", opts = { ensure_installed = { "netcoredbg" }, automatic_installation = true } },
      },
      config = function()
        local dap = require("dap")
        dap.set_log_level("INFO")
        local dapui = require("dapui")
        local netcoredbg = vim.fn.stdpath("data") .. "/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
        local function dotnet_project_file()
          local buffer_name = vim.api.nvim_buf_get_name(0)
          local start_path = buffer_name ~= "" and vim.fs.dirname(buffer_name) or vim.fn.getcwd()
          return vim.fs.find(function(name) return name:sub(-7) == ".csproj" end, {
            path = start_path,
            upward = true,
            limit = 1,
          })[1]
        end
        local function project_is_executable(project_file)
          if not project_file or vim.fn.filereadable(project_file) == 0 then return false end
          local project_text = table.concat(vim.fn.readfile(project_file), "\n")
          return project_text:match("<OutputType>%s*[Ww]?Exe%s*</OutputType>") ~= nil
        end
        local function debug_project_file()
          local nearest_project = dotnet_project_file()
          if project_is_executable(nearest_project) then return nearest_project end

          local start_path = nearest_project and vim.fs.dirname(nearest_project) or vim.fn.getcwd()
          local solution_file = vim.fs.find(function(name) return name:match("%.slnx?$") ~= nil end, {
            path = start_path,
            upward = true,
            limit = 1,
          })[1]
          if not solution_file then return nearest_project end

          local executable_projects = {}
          for _, project_file in ipairs(vim.fn.globpath(vim.fs.dirname(solution_file), "**/*.csproj", false, true)) do
            if project_is_executable(project_file) then table.insert(executable_projects, project_file) end
          end
          if #executable_projects == 1 then return executable_projects[1] end
          if #executable_projects > 1 then
            local choices = { "Select executable project:" }
            for index, project_file in ipairs(executable_projects) do
              choices[index + 1] = vim.fn.fnamemodify(project_file, ":.")
            end
            local selection = vim.fn.inputlist(choices)
            return executable_projects[selection]
          end
          return nearest_project
        end
        local function dotnet_program()
          local project_file = debug_project_file()
          if project_file then
            local project_dir = vim.fs.dirname(project_file)
            local project_name = vim.fn.fnamemodify(project_file, ":t:r")
            for _, dll in ipairs(vim.fn.globpath(project_dir, "bin/Debug/**/*.dll", false, true)) do
              local runtime_config = dll:gsub("%.dll$", ".runtimeconfig.json")
              if vim.fn.fnamemodify(dll, ":t") == project_name .. ".dll" and vim.fn.filereadable(runtime_config) == 1 then
                return dll
              end
            end
            return vim.fn.input("Path to DLL: ", project_dir .. "/bin/Debug/", "file")
          end
          return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
        end
        local function dotnet_launch_profile()
          local project_file = debug_project_file()
          if not project_file then return { cwd = vim.fn.getcwd(), args = {}, env = {} } end

          local project_dir = vim.fs.dirname(project_file)
          local launch_settings = project_dir .. "/Properties/launchSettings.json"
          if vim.fn.filereadable(launch_settings) == 0 then
            return { cwd = project_dir, args = {}, env = {} }
          end

          local ok, settings = pcall(vim.json.decode, table.concat(vim.fn.readfile(launch_settings), "\n"))
          if not ok then
            vim.notify("Could not read launchSettings.json", vim.log.levels.WARN)
            return { cwd = project_dir, args = {}, env = {} }
          end

          for _, profile in pairs(settings.profiles or {}) do
            if profile.commandName == "Project" then
              local args = profile.commandLineArgs and require("dap.utils").splitstr(profile.commandLineArgs) or {}
              return { cwd = project_dir, args = args, env = profile.environmentVariables or {} }
            end
          end
          return { cwd = project_dir, args = {}, env = {} }
        end
        dap.adapters.coreclr = { type = "executable", command = netcoredbg, args = { "--interpreter=vscode" } }
        dap.configurations.cs = {
          {
            type = "coreclr", name = "Launch .NET project", request = "launch",
            program = dotnet_program,
            args = function() return dotnet_launch_profile().args end,
            cwd = function() return dotnet_launch_profile().cwd end,
            env = function() return dotnet_launch_profile().env end,
            stopAtEntry = false,
          },
        }
        dap.listeners.after.event_initialized["dapui"] = dapui.open
        dap.listeners.before.event_terminated["dapui"] = dapui.close
        dap.listeners.before.event_exited["dapui"] = dapui.close
        vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Continue" })
        vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step over" })
        vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step into" })
        vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step out" })
        vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
        vim.keymap.set("n", "<leader>bc", dap.clear_breakpoints, { desc = "Debug: Clear all breakpoints" })
        vim.keymap.set("n", "<leader>B", function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, { desc = "Debug: Conditional breakpoint" })
        vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
        vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
      end,
    },
  }, { checker = { enabled = true }, change_detection = { notify = false } })

  vim.cmd.colorscheme("tokyonight")
  vim.api.nvim_set_hl(0, "VirtColumn", { fg = "#3b4261" })

end

return M
