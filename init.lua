-- C#-oriented Neovim configuration. Leader stays in the Vim tradition: Space.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.list = true
vim.opt.listchars = { space = "·", multispace = "·", tab = "→ " }

local terminal_buf
local function show_terminal()
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(window) == terminal_buf then
        return
      end
    end
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, terminal_buf)
  else
    vim.cmd("botright 15split | terminal")
    terminal_buf = vim.api.nvim_get_current_buf()
  end
  vim.cmd("startinsert")
end
local function toggle_terminal()
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(window) == terminal_buf then
        vim.api.nvim_win_close(window, true)
        return
      end
    end
  end
  show_terminal()
end
local function run_in_terminal(command)
  show_terminal()
  local job_id = vim.b[terminal_buf].terminal_job_id
  if job_id then vim.fn.chansend(job_id, command .. "\n") end
end
vim.keymap.set("n", "<leader>tt", toggle_terminal, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>tw", function() run_in_terminal("dotnet test --watch") end, { desc = "Test: Watch" })
vim.keymap.set("n", "<leader>rr", function() run_in_terminal("dotnet test") end, { desc = "Test: Run suite" })

vim.keymap.set("n", "<leader>R", "<CMD>Lazy sync<CR>", { desc = "Sync plugins" })

local function namespace_root_from_project(project_file)
  local project_dir = vim.fs.dirname(project_file)
  for _, line in ipairs(vim.fn.readfile(project_file)) do
    local root_namespace = line:match("<RootNamespace>([%w_.]+)</RootNamespace>")
    if root_namespace then return root_namespace end
  end

  for _, source_file in ipairs(vim.fn.globpath(project_dir, "**/*.cs", false, true)) do
    if not source_file:find("/bin/") and not source_file:find("/obj/") then
      for _, line in ipairs(vim.fn.readfile(source_file)) do
        local namespace = line:match("^%s*namespace%s+([%w_.]+)%s*[;{]")
        if namespace then
          local relative_dir = vim.fs.relpath(project_dir, vim.fs.dirname(source_file))
          if relative_dir and relative_dir ~= "." then
            local suffix = "." .. relative_dir:gsub("[/\\]", ".")
            if namespace:sub(-#suffix) == suffix then return namespace:sub(1, #namespace - #suffix) end
          end
          return namespace
        end
      end
    end
  end
  return vim.fn.fnamemodify(project_file, ":t:r")
end

vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  pattern = "*.cs",
  callback = function(event)
    local filename = vim.api.nvim_buf_get_name(event.buf)
    -- BufReadPost is included so `touch NewClass.cs` works too; only empty
    -- files receive a namespace.
    if event.event == "BufReadPost" and vim.fn.getfsize(filename) ~= 0 then return end
    if vim.api.nvim_buf_get_lines(event.buf, 0, -1, false)[1] ~= "" then return end

    local file_dir = vim.fs.dirname(filename)
    local project_file = vim.fs.find(function(name) return name:sub(-7) == ".csproj" end, {
      path = file_dir,
      upward = true,
      limit = 1,
    })[1]
    if not project_file then return end

    local project_dir = vim.fs.dirname(project_file)
    local relative_dir = vim.fs.relpath(project_dir, file_dir)
    local namespace = namespace_root_from_project(project_file)
    if relative_dir and relative_dir ~= "." then
      namespace = namespace .. "." .. relative_dir:gsub("[/\\]", "."):gsub("[^%w_.]", "_")
    end
    vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, { "namespace " .. namespace .. ";", "", "" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
  end,
})

-- In the file tree the selected row is clearer than a block cursor drawn over an icon.
local default_guicursor = vim.o.guicursor
local tree_guicursor = "n-v-c:ver1-CursorLine,i-ci-ve:ver25,r-cr:hor20,o:hor50"
vim.api.nvim_create_autocmd("FileType", {
  pattern = "NvimTree",
  callback = function(event)
    local function use_tree_cursor() vim.o.guicursor = tree_guicursor end
    local function use_default_cursor() vim.o.guicursor = default_guicursor end
    vim.wo.cursorline = true
    local winhighlight = vim.wo.winhighlight
    vim.wo.winhighlight = winhighlight == "" and "Cursor:CursorLine" or winhighlight .. ",Cursor:CursorLine"
    use_tree_cursor()
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { buffer = event.buf, callback = use_tree_cursor })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { buffer = event.buf, callback = use_default_cursor })
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.notify("lazy.nvim is missing. Run the setup command again.", vim.log.levels.ERROR)
  return
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "folke/tokyonight.nvim", priority = 1000, opts = { style = "moon" } },
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
        { "<leader>r", group = "Refactor / Run" },
        { "<leader>t", group = "Terminal / Test" },
        { "<leader>R", desc = "Sync plugins" },
      },
    },
  },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "lewis6991/gitsigns.nvim", opts = {} },
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
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          sorting_strategy = "ascending",
          disable_devicons = true,
        },
      })
      pcall(telescope.load_extension, "fzf")
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Search project text" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Search help" })
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = { ensure_installed = { "csharp_ls" }, automatic_installation = true },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("csharp_ls", {
        capabilities = capabilities,
        settings = {
          ["csharp|inlay_hints"] = { csharp_enable_inlay_hints_for_implicit_object_creation = true },
        },
      })
      vim.lsp.enable("csharp_ls")
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Documentation")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>e", vim.diagnostic.open_float, "Diagnostics")
          map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
          map("]d", vim.diagnostic.goto_next, "Next diagnostic")
        end,
      })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { cs = { "csharpier" } },
      format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
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
      local function dotnet_program()
        local project_file = dotnet_project_file()
        if project_file then
          local project_dir = vim.fs.dirname(project_file)
          local project_name = vim.fn.fnamemodify(project_file, ":t:r")
          for _, dll in ipairs(vim.fn.globpath(project_dir, "bin/Debug/**/*.dll", false, true)) do
            if vim.fn.fnamemodify(dll, ":t") == project_name .. ".dll" then return dll end
          end
          return vim.fn.input("Path to DLL: ", project_dir .. "/bin/Debug/", "file")
        end
        return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
      end
      local function dotnet_launch_profile()
        local project_file = dotnet_project_file()
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
