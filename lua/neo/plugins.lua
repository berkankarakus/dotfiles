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
      opts = { char = "┊", virtcolumn = "120", exclude = { filetypes = { "NvimTree" } } },
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
        treesitter.install({ "c_sharp", "mssql" })
        vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime")
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      branch = "main",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      lazy = false,
      config = function()
        require("nvim-treesitter-textobjects").setup({
          select = {
            lookahead = true,
            include_surrounding_whitespace = false,
          },
          move = { set_jumps = true },
        })

        local select = require("nvim-treesitter-textobjects.select")
        local move = require("nvim-treesitter-textobjects.move")
        local shared = require("nvim-treesitter-textobjects.shared")
        local function map_textobject(keys, query, desc)
          vim.keymap.set({ "x", "o" }, keys, function()
            select.select_textobject(query, "textobjects")
          end, { desc = desc })
        end
        local function goto_range(range, at_end)
          if not range or not range[1] then return end
          vim.cmd("normal! m'")
          if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end

          local row, column
          if at_end then
            row, column = range[4], range[5]
            if column == 0 then
              row = row - 1
              column = #vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
            else
              column = column - 1
            end
          else
            row, column = range[1], range[2]
          end
          vim.api.nvim_win_set_cursor(0, { row + 1, column })
        end
        local function move_with_wrap(query, forward, at_end)
          local cursor_before = vim.api.nvim_win_get_cursor(0)
          if forward and at_end then
            move.goto_next_end(query, "textobjects")
          elseif forward then
            move.goto_next_start(query, "textobjects")
          elseif at_end then
            move.goto_previous_end(query, "textobjects")
          else
            move.goto_previous_start(query, "textobjects")
          end
          if not vim.deep_equal(cursor_before, vim.api.nvim_win_get_cursor(0)) then return end

          local range_index = at_end and 6 or 3
          local range = shared.find_best_range(0, query, "textobjects", function()
            return true
          end, function(candidate)
            return forward and -candidate[range_index] or candidate[range_index]
          end)
          goto_range(range, at_end)
        end
        local function map_textobject_move(next_start, previous_start, next_end, previous_end, query, desc)
          vim.keymap.set({ "n", "x", "o" }, next_start, function()
            move_with_wrap(query, true, false)
          end, { desc = "Next " .. desc })
          vim.keymap.set({ "n", "x", "o" }, previous_start, function()
            move_with_wrap(query, false, false)
          end, { desc = "Previous " .. desc })
          vim.keymap.set({ "n", "x", "o" }, next_end, function()
            move_with_wrap(query, true, true)
          end, { desc = "Next " .. desc .. " end" })
          vim.keymap.set({ "n", "x", "o" }, previous_end, function()
            move_with_wrap(query, false, true)
          end, { desc = "Previous " .. desc .. " end" })
        end
        local function map_textobject_start(next_start, previous_start, query, desc)
          vim.keymap.set({ "n", "x", "o" }, next_start, function()
            move_with_wrap(query, true, false)
          end, { desc = "Next " .. desc })
          vim.keymap.set({ "n", "x", "o" }, previous_start, function()
            move_with_wrap(query, false, false)
          end, { desc = "Previous " .. desc })
        end
        local function move_csharp_statement(forward)
          local ok, parser = pcall(vim.treesitter.get_parser, 0, "c_sharp")
          if not ok then return end
          local query = vim.treesitter.query.get("c_sharp", "textobjects")
          if not query then return end

          local statements = {}
          for capture_id, node in query:iter_captures(parser:parse()[1]:root(), 0, 0, -1) do
            local capture = query.captures[capture_id]
            if (capture == "statement.outer" or capture == "declaration.outer") and node:type() ~= "block" then
              local start_row, start_column = node:start()
              statements[#statements + 1] = { node = node, row = start_row, column = start_column }
            end
          end
          if #statements == 0 then return end
          table.sort(statements, function(left, right)
            return left.row < right.row or (left.row == right.row and left.column < right.column)
          end)

          local cursor_row, cursor_column = unpack(vim.api.nvim_win_get_cursor(0))
          cursor_row = cursor_row - 1
          local target
          if forward then
            for _, statement in ipairs(statements) do
              if statement.row > cursor_row or (statement.row == cursor_row and statement.column > cursor_column) then
                target = statement
                break
              end
            end
            target = target or statements[1]
          else
            for index = #statements, 1, -1 do
              local statement = statements[index]
              if statement.row < cursor_row or (statement.row == cursor_row and statement.column < cursor_column) then
                target = statement
                break
              end
            end
            target = target or statements[#statements]
          end

          vim.cmd("normal! m'")
          if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end
          vim.api.nvim_win_set_cursor(0, { target.row + 1, target.column })
        end
        local function map_sql_clause(next_start, previous_start)
          local function move_clause(forward)
            if vim.bo.filetype == "cs" or vim.bo.filetype == "c_sharp" then
              move_csharp_statement(forward)
              return
            end
            local ok, parser = pcall(vim.treesitter.get_parser, 0)
            if not ok then return end
            local row, column = unpack(vim.api.nvim_win_get_cursor(0))
            row = row - 1
            local node = parser:parse()[1]:root():named_descendant_for_range(row, column, row, column)
            local clause_types, scope_node, query_specification
            while node do
              if node:type() == "query_specification" then
                query_specification = node
                scope_node = node
                clause_types = { select = true, from = true, where = true, group_by = true, having = true }
                break
              elseif node:type() == "statement" then
                for child in node:iter_children() do
                  if child:type() == "query_specification" then
                    query_specification = child
                    scope_node = child
                    clause_types = { select = true, from = true, where = true, group_by = true, having = true }
                    break
                  end
                end
                if query_specification then break end
                node = node:parent()
              elseif node:type() == "update" then
                scope_node = node
                clause_types = { keyword_update = true, keyword_set = true, from = true, where = true }
                break
              elseif node:type() == "delete" then
                scope_node = node
                clause_types = { keyword_delete = true, from = true, where = true }
                break
              else
                node = node:parent()
              end
            end
            if not scope_node then return end

            local clauses = {}
            for child in scope_node:iter_children() do
              if clause_types[child:type()] then clauses[#clauses + 1] = child end
              if child:type() == "from" then
                for from_child in child:iter_children() do
                  if from_child:type() == "join" then clauses[#clauses + 1] = from_child end
                end
              end
            end
            if query_specification then
              local statement = query_specification:parent()
              if statement and statement:type() == "statement" then
                for child in statement:iter_children() do
                  local child_type = child:type()
                  if child_type == "order_by" or child_type == "offset_fetch" then
                    clauses[#clauses + 1] = child
                  end
                end
              end
              table.sort(clauses, function(left, right)
                local left_row, left_column = left:range()
                local right_row, right_column = right:range()
                return left_row < right_row or (left_row == right_row and left_column < right_column)
              end)
            end
            if #clauses == 0 then return end

            local target
            if forward then
              for _, clause in ipairs(clauses) do
                local clause_row, clause_column = clause:range()
                if clause_row > row or (clause_row == row and clause_column > column) then
                  target = clause
                  break
                end
              end
              target = target or clauses[1]
            else
              for index = #clauses, 1, -1 do
                local clause_row, clause_column = clauses[index]:range()
                if clause_row < row or (clause_row == row and clause_column < column) then
                  target = clauses[index]
                  break
                end
              end
              target = target or clauses[#clauses]
            end

            vim.cmd("normal! m'")
            if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end
            local target_row, target_column = target:range()
            vim.api.nvim_win_set_cursor(0, { target_row + 1, target_column })
          end
          vim.keymap.set({ "n", "x", "o" }, next_start, function()
            move_clause(true)
          end, { desc = "Next SQL clause" })
          vim.keymap.set({ "n", "x", "o" }, previous_start, function()
            move_clause(false)
          end, { desc = "Previous SQL clause" })
        end
        local function map_sql_query(next_start, previous_start)
          local function go_to_parent_scope()
            local ok, parser = pcall(vim.treesitter.get_parser, 0)
            if not ok then return false end
            local row, column = unpack(vim.api.nvim_win_get_cursor(0))
            local node = parser:parse()[1]:root():named_descendant_for_range(row - 1, column, row - 1, column)
            while node and node:type() ~= "query_specification" do
              node = node:parent()
            end
            if not node then return false end

            node = node:parent()
            while node do
              local node_type = node:type()
              if node_type == "query_specification" or node_type == "update" or node_type == "delete" then
                local target_row, target_column = node:range()
                goto_range({ target_row, target_column, 0, target_row, target_column, 0 }, false)
                return true
              end
              node = node:parent()
            end
            return false
          end
          vim.keymap.set({ "n", "x", "o" }, next_start, function()
            move_with_wrap("@query.outer", true, false)
          end, { desc = "Next SQL query" })
          vim.keymap.set({ "n", "x", "o" }, previous_start, function()
            if not go_to_parent_scope() then move_with_wrap("@query.outer", false, false) end
          end, { desc = "Parent SQL query or statement" })
        end

        map_textobject("ab", "@block.outer", "Select around block")
        map_textobject("ib", "@block.contents", "Select block contents")
        map_textobject("af", "@function.outer", "Select around function")
        map_textobject("if", "@function.inner", "Select inside function")
        map_textobject("al", "@loop.outer", "Select around loop")
        map_textobject("il", "@loop.contents", "Select loop contents")
        map_textobject("aC", "@conditional.outer", "Select around conditional")
        map_textobject("iC", "@conditional.contents", "Select conditional contents")
        map_textobject("ac", "@class.outer", "Select around class")
        map_textobject("ic", "@class.inner", "Select inside class")
        map_textobject("aa", "@parameter.outer", "Select around parameter")
        map_textobject("ia", "@parameter.inner", "Select inside parameter")
        map_textobject("aq", "@query.outer", "Select around SQL query")
        map_textobject("aS", "@statement.outer", "Select around SQL statement")

        map_textobject_move("]f", "[f", "]F", "[F", "@function.outer", "function")
        map_textobject_move("]c", "[c", "]C", "[C", "@conditional.outer", "conditional")
        map_sql_query("]r", "[r")
        map_sql_clause("]k", "[k")
        map_textobject_start("]s", "[s", "@statement.outer", "SQL statement")
        map_textobject_start("]K", "[K", "@switch.case", "C# switch case")
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
          commands = {
            ["roslyn.client.nestedCodeAction"] = function(data, ctx)
              local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
              local nested_actions = data.arguments[1].NestedCodeActions or {}
              local code_actions = vim.tbl_map(function(code_action)
                local action_data = code_action.data
                local path = action_data.CodeActionPath
                local title = #path == 1 and path[1] or table.concat(path, " -> ", 2)
                if action_data.FixAllFlavors then title = "Fix All: " .. title end
                return { title = title, code_action = code_action }
              end, nested_actions)

              vim.ui.select(code_actions, {
                prompt = data.arguments[1].UniqueIdentifier,
                format_item = function(action) return action.title end,
              }, function(action)
                if not action then return end

                if action.code_action.data.FixAllFlavors then
                  vim.lsp.config.roslyn.commands["roslyn.client.fixAllCodeAction"](action.code_action.command, ctx)
                  return
                end

                client:request("codeAction/resolve", {
                  title = action.code_action.title,
                  data = action.code_action.data,
                }, function(err, response)
                  if err then vim.notify(err.message, vim.log.levels.ERROR, { title = "roslyn.nvim" }) end
                  if response and response.edit then
                    vim.lsp.util.apply_workspace_edit(response.edit, client.offset_encoding)
                  end
                end)
              end)
            end,
          },
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
      event = "InsertEnter",
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
      event = "BufReadPost *.cs",
      keys = {
        { "<F5>", desc = "Debug: Continue" },
        { "<F10>", desc = "Debug: Step over" },
        { "<F11>", desc = "Debug: Step into" },
        { "<F12>", desc = "Debug: Step out" },
        { "<leader>b", desc = "Debug: Toggle breakpoint" },
        { "<leader>bc", desc = "Debug: Clear all breakpoints" },
        { "<leader>B", desc = "Debug: Conditional breakpoint" },
        { "<leader>dr", desc = "Debug: Open REPL" },
        { "<leader>du", desc = "Debug: Toggle UI" },
      },
      dependencies = {
        { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
        { "Cliffback/netcoredbg-macOS-arm64.nvim" },
        { "jay-babu/mason-nvim-dap.nvim", opts = { ensure_installed = { "netcoredbg" }, automatic_installation = true } },
        { "Weissle/persistent-breakpoints.nvim" },
      },
      config = function()
        local dap = require("dap")
        dap.set_log_level("INFO")
        local dapui = require("dapui")
        require("persistent-breakpoints").setup({ load_breakpoints_event = { "BufReadPost" } })
        local persistent_breakpoints = require("persistent-breakpoints.api")
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
        local function project_sdk(project_file)
          if not project_file or vim.fn.filereadable(project_file) == 0 then return false end
          local project_text = table.concat(vim.fn.readfile(project_file), "\n")
          return project_text:match('<Project[^>]-Sdk%s*=%s*["\']([^"\']+)["\']')
        end
        local function project_is_executable(project_file)
          if not project_file or vim.fn.filereadable(project_file) == 0 then return false end
          local project_text = table.concat(vim.fn.readfile(project_file), "\n")
          local has_executable_output = project_text:match("<OutputType>%s*[Ww]?Exe%s*</OutputType>") ~= nil
          local sdk = project_sdk(project_file)
          return has_executable_output or sdk == "Microsoft.NET.Sdk.Web" or sdk == "Microsoft.NET.Sdk.Worker"
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
        local function dotnet_program(project_file)
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
        local function dotnet_launch_profile(project_file)
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
              local env = vim.deepcopy(profile.environmentVariables or {})
              if profile.applicationUrl and not env.ASPNETCORE_URLS then
                env.ASPNETCORE_URLS = profile.applicationUrl
              end

              local browser_url
              if project_sdk(project_file) == "Microsoft.NET.Sdk.Web" and profile.launchBrowser and profile.applicationUrl then
                local base_url = vim.split(profile.applicationUrl, ";", { plain = true })[1]
                local launch_path = profile.launchUrl or ""
                browser_url = base_url:gsub("/$", "")
                if launch_path ~= "" then browser_url = browser_url .. "/" .. launch_path:gsub("^/", "") end
              end
              return { cwd = project_dir, args = args, env = env, browser_url = browser_url }
            end
          end
          return { cwd = project_dir, args = {}, env = {}, browser_url = nil }
        end
        local launch_context = require("neo.dotnet_debug").launch_context_cache(function()
          local project_file = debug_project_file()
          return {
            program = dotnet_program(project_file),
            profile = dotnet_launch_profile(project_file),
          }
        end)
        local function current_launch_context()
          return launch_context.get()
        end
        dap.adapters.coreclr = { type = "executable", command = netcoredbg, args = { "--interpreter=vscode" } }
        dap.configurations.cs = {
          {
            type = "coreclr", name = "Launch .NET project", request = "launch",
            program = function() return current_launch_context().program end,
            args = function() return current_launch_context().profile.args end,
            cwd = function() return current_launch_context().profile.cwd end,
            env = function() return current_launch_context().profile.env end,
            stopAtEntry = false,
          },
        }
        dap.listeners.after.event_initialized["dapui"] = function()
          local browser_url = current_launch_context().profile.browser_url
          dapui.open()
          if browser_url then
            vim.defer_fn(function() vim.ui.open(browser_url) end, 1500)
          end
        end
        local terminal_bundle_ids = {
          Apple_Terminal = "com.apple.Terminal",
          Ghostty = "com.mitchellh.ghostty",
          ghostty = "com.mitchellh.ghostty",
          iTerm = "com.googlecode.iterm2",
          iTerm2 = "com.googlecode.iterm2",
          WezTerm = "com.github.wez.wezterm",
        }
        local terminal_bundle_id = terminal_bundle_ids[vim.env.TERM_PROGRAM]
        local terminal_notifier = vim.fn.exepath("terminal-notifier")
        dap.listeners.after.event_stopped["debug-notification"] = function(_, body)
          if body.reason ~= "breakpoint" then return end

          local message = "Breakpoint reached."
          vim.notify(message, vim.log.levels.INFO, { title = "Neovim Debugger" })

          if terminal_notifier ~= "" then
            local command = { terminal_notifier, "-title", "Neovim Debugger", "-message", message }
            if terminal_bundle_id then
              vim.list_extend(command, { "-activate", terminal_bundle_id })
            end
            vim.fn.jobstart(command, { detach = true })
          end
        end
        local function close_debug_ui()
          launch_context.reset()
          dapui.close()
        end
        dap.listeners.before.event_terminated["dapui"] = close_debug_ui
        dap.listeners.before.event_exited["dapui"] = close_debug_ui
        vim.keymap.set("n", "<F5>", function()
          if not dap.session() then launch_context.reset() end
          dap.continue()
        end, { desc = "Debug: Continue" })
        vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step over" })
        vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step into" })
        vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step out" })
        vim.keymap.set("n", "<leader>b", persistent_breakpoints.toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
        vim.keymap.set("n", "<leader>bc", persistent_breakpoints.clear_all_breakpoints, { desc = "Debug: Clear all breakpoints" })
        vim.keymap.set("n", "<leader>B", persistent_breakpoints.set_conditional_breakpoint, { desc = "Debug: Conditional breakpoint" })
        vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
        vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
      end,
    },
  }, { checker = { enabled = true }, change_detection = { notify = false } })

  vim.cmd.colorscheme("tokyonight")
  vim.api.nvim_set_hl(0, "VirtColumn", { fg = "#3b4261" })

end

return M
