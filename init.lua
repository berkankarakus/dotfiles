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
vim.opt.shortmess:append("W")
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.list = true
vim.opt.listchars = { space = "·", multispace = "·", tab = "→ " }
vim.opt.colorcolumn = "80"
vim.opt.whichwrap:append("[")
vim.opt.whichwrap:append("]")
vim.opt.whichwrap:append("<")
vim.opt.whichwrap:append(">")
vim.opt.whichwrap:append("h")
vim.opt.whichwrap:append("l")

local function move_word_within_line(direction)
  local line = vim.api.nvim_get_current_line()
  local column = vim.api.nvim_win_get_cursor(0)[2]
  if direction == "left" then
    if line:sub(1, column):match("%S") then return "<C-o>b" end
    return "<C-o>0"
  end
  if line:sub(column + 1):match("%s+%S") then return "<C-o>w" end
  return "<C-o>$"
end

vim.keymap.set("i", "<M-f>", function() return move_word_within_line("right") end, { expr = true, desc = "Next word on line" })
vim.keymap.set("i", "<M-Right>", function() return move_word_within_line("right") end, { expr = true, desc = "Next word on line" })
vim.keymap.set("i", "<M-b>", function() return move_word_within_line("left") end, { expr = true, desc = "Previous word on line" })
vim.keymap.set("i", "<M-Left>", function() return move_word_within_line("left") end, { expr = true, desc = "Previous word on line" })
vim.keymap.set("i", "<M-d>", "<C-o>dw", { desc = "Delete next word" })
vim.keymap.set("i", "<Home>", "<C-o>0", { desc = "Start of line" })
vim.keymap.set("i", "<End>", "<C-o>$", { desc = "End of line" })
vim.keymap.set("n", "<S-Up>", "<CMD>move .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<S-Down>", "<CMD>move .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("x", "<S-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("x", "<S-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })

vim.keymap.set("c", "<CR>", function()
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "q" then
    return "<C-u>wall | q<CR>"
  end
  return "<CR>"
end, { expr = true, desc = "Save all before quit" })

local csharp_fold_cache = {}
function _G.csharp_foldexpr()
  local bufnr = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cache = csharp_fold_cache[bufnr]
  if not cache or cache.tick ~= tick then
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local levels, region_depth = {}, 0
    for line_number = 1, line_count do
      local line = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
      if line:match("^%s*#%s*region%f[%W]") then region_depth = region_depth + 1 end
      levels[line_number] = region_depth
      if line:match("^%s*#%s*endregion%f[%W]") then region_depth = math.max(region_depth - 1, 0) end
    end

    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, "c_sharp")
    if parser_ok then
      local tree = parser:parse()[1]
      local query = vim.treesitter.query.get("c_sharp", "folds")
      for capture_id, node in query:iter_captures(tree:root(), bufnr) do
        if query.captures[capture_id] == "fold" then
          local start_row, _, end_row, end_column = node:range()
          local start_line = start_row + 1
          local end_line = end_row + (end_column > 0 and 1 or 0)
          if end_line > start_line then
            for line_number = start_line, math.min(end_line, line_count) do
              levels[line_number] = levels[line_number] + 1
            end
          end
        end
      end
    end
    cache = { tick = tick, levels = levels }
    csharp_fold_cache[bufnr] = cache
  end
  return cache.levels[vim.v.lnum] or 0
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cs",
  callback = function()
    vim.opt_local.formatoptions:remove({ "r", "o" })
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.csharp_foldexpr()"
    vim.opt_local.foldlevel = 99
    vim.opt_local.foldenable = true
    vim.opt_local.foldcolumn = "1"
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" or vim.bo[event.buf].filetype == "gitcommit" then return end
    if vim.api.nvim_win_get_buf(0) ~= event.buf then return end
    local last_position = vim.api.nvim_buf_get_mark(event.buf, '"')
    if last_position[1] > 0 and last_position[1] <= vim.api.nvim_buf_line_count(event.buf) then
      vim.api.nvim_win_set_cursor(0, last_position)
    end
  end,
})

local last_file_state = vim.fn.stdpath("state") .. "/last-file-by-directory.json"
local function project_key()
  return vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
end
local function read_last_files()
  local read_ok, lines = pcall(vim.fn.readfile, last_file_state)
  if not read_ok then return {} end
  local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  return decode_ok and type(decoded) == "table" and decoded or {}
end
local function remember_last_file(event)
  if vim.bo[event.buf].buftype ~= "" then return end
  local file = vim.api.nvim_buf_get_name(event.buf)
  if file == "" or vim.fn.filereadable(file) == 0 then return end
  local root = project_key()
  local resolved_file = vim.uv.fs_realpath(file) or file
  if resolved_file:sub(1, #root + 1) ~= root .. "/" then return end
  local last_files = read_last_files()
  last_files[root] = resolved_file
  pcall(vim.fn.writefile, { vim.json.encode(last_files) }, last_file_state)
end
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, { callback = remember_last_file })

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) == 0 then return end
    local root = project_key()
    local file = read_last_files()[root]
    if not file or vim.fn.filereadable(file) == 0 then
      for _, old_file in ipairs(vim.v.oldfiles) do
        local resolved_file = vim.uv.fs_realpath(old_file) or old_file
        if resolved_file:sub(1, #root + 1) == root .. "/" and vim.fn.filereadable(resolved_file) == 1 then
          file = resolved_file
          break
        end
      end
    end
    if file then vim.schedule(function() vim.cmd.edit(vim.fn.fnameescape(file)) end) end
  end,
})

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
  vim.wo.colorcolumn = ""
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
vim.keymap.set("t", "<C-\\>", function()
  vim.cmd("stopinsert")
  vim.schedule(toggle_terminal)
end, { desc = "Hide terminal", nowait = true })
vim.keymap.set("n", "<leader>tw", function() run_in_terminal("dotnet test --watch") end, { desc = "Test: Watch" })
vim.keymap.set("n", "<leader>rr", function() run_in_terminal("dotnet test") end, { desc = "Test: Run suite" })

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

local function insert_csharp_docstring()
  if vim.bo.filetype ~= "cs" then
    vim.notify("Docstring shortcut is only available in C# files.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local declaration = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  while declaration:match("^%s*$") and line_number < vim.api.nvim_buf_line_count(bufnr) do
    line_number = line_number + 1
    declaration = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  end
  if declaration:match("^%s*$") then
    vim.notify("Place the cursor on a C# declaration or the blank line directly above it.", vim.log.levels.WARN)
    return
  end

  local previous_line = line_number - 1
  local previous = ""
  while previous_line > 0 do
    previous = vim.api.nvim_buf_get_lines(bufnr, previous_line - 1, previous_line, false)[1]
    if not previous:match("^%s*$") then break end
    previous_line = previous_line - 1
  end
  if previous:match("^%s*///") then
    vim.notify("This declaration already has a docstring.", vim.log.levels.INFO)
    return
  end

  local indent = declaration:match("^(%s*)") or ""
  local lines = { indent .. "/// <summary>", indent .. "/// ", indent .. "/// </summary>" }
  local signature = declaration
  for next_line = line_number + 1, math.min(line_number + 6, vim.api.nvim_buf_line_count(bufnr)) do
    if signature:find("%(") and signature:find("%)") then break end
    signature = signature .. " " .. vim.api.nvim_buf_get_lines(bufnr, next_line - 1, next_line, false)[1]
  end

  local parameters = signature:match("%b()")
  if parameters then
    for parameter in parameters:sub(2, -2):gmatch("[^,]+") do
      local name = parameter:gsub("=.*", ""):match("([%a_][%w_]*)%s*$")
      if name then table.insert(lines, indent .. '/// <param name="' .. name .. '"></param>') end
    end
  end

  local before_method = signature:match("^(.-)%s+[%a_][%w_]*%s*%(")
  local return_type = before_method and before_method:match("([%w_%.<>%[%]?]+)%s*$")
  local current_class
  for search_line = line_number, 1, -1 do
    current_class = vim.api.nvim_buf_get_lines(bufnr, search_line - 1, search_line, false)[1]:match("class%s+([%w_]+)")
    if current_class then break end
  end
  if return_type and return_type ~= "void" and return_type ~= current_class then
    table.insert(lines, indent .. "/// <returns></returns>")
  end

  vim.api.nvim_buf_set_lines(bufnr, line_number - 1, line_number - 1, false, lines)
  vim.api.nvim_win_set_cursor(0, { line_number + 1, #indent + 4 })
  vim.cmd("startinsert")
  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.keycode("<Right>"), "n", false)
  end)
end

-- In the file tree the selected row is clearer than a block cursor drawn over an icon.
local default_guicursor = vim.o.guicursor
local tree_guicursor = "n-v-c:ver1-CursorLine,i-ci-ve:ver25,r-cr:hor20,o:hor50"
vim.api.nvim_create_autocmd("FileType", {
  pattern = "NvimTree",
  callback = function(event)
    local function use_tree_cursor() vim.o.guicursor = tree_guicursor end
    local function use_default_cursor() vim.o.guicursor = default_guicursor end
    vim.wo.cursorline = true
    vim.wo.colorcolumn = ""
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
    "lukas-reineke/virt-column.nvim",
    opts = { char = "┊" },
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
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
    keys = {
      { "]h", function() require("gitsigns").next_hunk() end, desc = "Next Git hunk" },
      { "[h", function() require("gitsigns").prev_hunk() end, desc = "Previous Git hunk" },
      { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Preview Git hunk" },
      { "<leader>gr", function() require("gitsigns").reset_hunk() end, desc = "Revert Git hunk" },
      { "<leader>gs", function() require("gitsigns").stage_hunk() end, desc = "Stage Git hunk" },
      { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, desc = "Git blame line" },
    },
  },
  { "echasnovski/mini.surround", version = false, opts = {} },
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
        telescope.extensions.frecency.frecency({ workspace = "CWD" })
      end, { desc = "Find files (recent first)" })
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
      vim.lsp.config("roslyn", {
        capabilities = capabilities,
        cmd = { vim.fn.expand("~/.dotnet/tools/roslyn-language-server"), "--stdio" },
        settings = {
          ["csharp|inlay_hints"] = { csharp_enable_inlay_hints_for_implicit_object_creation = true },
          ["csharp|completion"] = { dotnet_show_completion_items_from_unimported_namespaces = true },
        },
      })
      vim.lsp.enable("roslyn")
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          local code_action = function()
            vim.lsp.buf.code_action()
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Documentation")
          map("<leader>s", vim.lsp.buf.signature_help, "Signature help")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          vim.keymap.set({ "n", "x" }, "<leader>ca", code_action, { buffer = event.buf, desc = "Code action" })
          map("<leader>cd", insert_csharp_docstring, "Insert C# docstring")
          map("<leader>e", vim.diagnostic.open_float, "Diagnostics")
          map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
          map("]d", vim.diagnostic.goto_next, "Next diagnostic")

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
        s("for", { t("for (var i = 0; i < "), i(1, "count"), t({ "; i++ )", "{", "    " }), i(0), t({ "", "}" }) }),
        s("foreach", { t("foreach (var "), i(1, "item"), t(" in "), i(2, "items"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("dowhile", { t({ "do", "{", "    " }), i(1), t({ "", "} while (" }), i(2, "condition"), t(");"), i(0) }),
        s("region", { t("#region "), i(1, "Name"), t({ "", "" }), i(0), t({ "", "#endregion" }) }),
        s("try", { t({ "try", "{", "    " }), i(1), t({ "", "}", "catch (" }), i(2, "Exception ex"), t({ ")", "{", "    " }), i(0), t({ "", "}" }) }),
        s("cw", { t("Console.WriteLine("), i(1), t(");") }),
      })
      cmp.setup({
        snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif ls.expand_or_locally_jumpable() then ls.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif ls.locally_jumpable(-1) then ls.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      -- C# formatting is delegated to Roslyn so project .editorconfig rules apply.
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
