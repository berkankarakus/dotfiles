local M = {}

function M.setup()
  local function move_right_within_line()
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local tail = line:sub(column + 1)
    local _, word_end = tail:find("^[%w_]+")
    if word_end then
      vim.api.nvim_win_set_cursor(0, { row, column + word_end })
      return
    end

    local next_character = tail:find("%S")
    if next_character then
      vim.api.nvim_win_set_cursor(0, { row, column + math.max(1, next_character - 1) })
      return
    end

    for next_row = row + 1, vim.api.nvim_buf_line_count(bufnr) do
      local next_line = vim.api.nvim_buf_get_lines(bufnr, next_row - 1, next_row, false)[1]
      local first_character = next_line:find("%S")
      if first_character then
        vim.api.nvim_win_set_cursor(0, { next_row, first_character - 1 })
        return
      end
    end
  end

  local function move_left_within_line()
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local prefix = line:sub(1, column)
    local last_nonspace = prefix:match("^.*()%S")
    if last_nonspace then
      local word_start = prefix:sub(1, last_nonspace):find("[%w_]+$")
      if word_start then
        vim.api.nvim_win_set_cursor(0, { row, word_start - 1 })
      else
        vim.api.nvim_win_set_cursor(0, { row, last_nonspace - 1 })
      end
      return
    end

    for previous_row = row - 1, 1, -1 do
      local previous_line = vim.api.nvim_buf_get_lines(bufnr, previous_row - 1, previous_row, false)[1]
      local last_character = previous_line:match("^.*()%S")
      if last_character then
        vim.api.nvim_win_set_cursor(0, { previous_row, last_character })
        return
      end
    end
  end

  local function delete_to_next_capital()
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local tail = line:sub(column + 1)
    if not tail:match("^[%w_]") then return end

    local word_end = tail:find("[^%w_]")
    word_end = word_end and word_end - 1 or #tail
    local next_capital = tail:find("[A-Z]", 2)
    local delete_length = (next_capital and next_capital <= word_end) and next_capital - 1 or word_end
    if delete_length == 0 then return end

    vim.api.nvim_buf_set_text(0, row - 1, column, row - 1, column + delete_length, {})
  end

  local function move_to_next_capital()
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    if not line:sub(1, column + 1):match("[%w_]$") then return end

    local remaining = line:sub(column + 2)
    local next_capital = remaining:find("[A-Z]")
    local word_end = remaining:find("[^%w_]")
    if next_capital and (not word_end or next_capital < word_end) then
      vim.api.nvim_win_set_cursor(0, { row, column + next_capital })
    end
  end

  local function move_to_previous_capital()
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    if not line:sub(column + 1, column + 1):match("[%w_]") then return end

    local before_cursor = line:sub(1, column)
    local word_before_cursor = before_cursor:match("([%w_]+)$")
    if not word_before_cursor then return end

    local previous_capital = word_before_cursor:match("^.*()[A-Z]")
    if previous_capital then
      vim.api.nvim_win_set_cursor(0, { row, #before_cursor - #word_before_cursor + previous_capital - 1 })
    end
  end

  local function smart_home()
    local line = vim.api.nvim_get_current_line()
    local first_nonblank = line:find("%S")
    if not first_nonblank then return "<C-o>0" end
    first_nonblank = first_nonblank - 1
    if vim.api.nvim_win_get_cursor(0)[2] == first_nonblank then return "<C-o>0" end
    return "<C-o>^"
  end

  local function smart_end()
    return "<C-o>$"
  end

  local function move_by_page(direction)
    local row, column = unpack(vim.api.nvim_win_get_cursor(0))
    local line_count = vim.api.nvim_buf_line_count(0)
    local page_height = math.max(1, vim.fn.winheight(0) - 2)
    local target_row = math.max(1, math.min(line_count, row + (direction * page_height)))
    local target_line = vim.api.nvim_buf_get_lines(0, target_row - 1, target_row, false)[1]
    vim.api.nvim_win_set_cursor(0, { target_row, math.min(column, #target_line) })
  end

  vim.keymap.set("i", "<M-f>", move_right_within_line, { desc = "Next word on line" })
  vim.keymap.set("i", "<M-Right>", move_right_within_line, { desc = "Next word on line" })
  vim.keymap.set("i", "<M-b>", move_left_within_line, { desc = "Previous word" })
  vim.keymap.set("i", "<M-Left>", move_left_within_line, { desc = "Previous word" })
  vim.keymap.set("i", "<M-d>", "<C-o>dw", { desc = "Delete next word" })
  vim.keymap.set("n", "<M-d>", delete_to_next_capital, { desc = "Delete to next capital" })
  vim.keymap.set("n", "<M-c>", move_to_next_capital, { desc = "Next capital in word" })
  vim.keymap.set("n", "<M-C>", move_to_previous_capital, { desc = "Previous capital in word" })
  vim.keymap.set("n", "<C-h>", "<cmd>wincmd h<CR>", { desc = "Focus left window" })
  vim.keymap.set("n", "<C-l>", "<cmd>wincmd l<CR>", { desc = "Focus right window" })
  vim.keymap.set("i", "<C-_>", "<C-o>u", { desc = "Undo" })
  vim.keymap.set("i", "<Home>", smart_home, { expr = true, desc = "Smart start of line" })
  vim.keymap.set("i", "<End>", smart_end, { expr = true, desc = "Smart end of line" })
  vim.keymap.set("i", "<S-Up>", function()
    vim.cmd("move .-2")
    vim.cmd("normal! ==")
  end, { desc = "Move line up" })
  vim.keymap.set("i", "<S-Down>", function()
    vim.cmd("move .+1")
    vim.cmd("normal! ==")
  end, { desc = "Move line down" })
  vim.keymap.set("n", "<S-Up>", "<CMD>move .-2<CR>==", { desc = "Move line up" })
  vim.keymap.set("n", "<S-Down>", "<CMD>move .+1<CR>==", { desc = "Move line down" })
  vim.keymap.set("x", "<S-Up>", ":move '<-2<CR>gv=gv", { desc = "Move selection up" })
  vim.keymap.set("x", "<S-Down>", ":move '>+1<CR>gv=gv", { desc = "Move selection down" })
  vim.keymap.set("n", "<PageUp>", function() move_by_page(-1) end, { desc = "Move cursor one page up" })
  vim.keymap.set("n", "<PageDown>", function() move_by_page(1) end, { desc = "Move cursor one page down" })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "cs",
    callback = function()
      -- Keep Neovim's built-in block-comment continuation, but exclude `//`.
      vim.opt_local.comments = vim.bo.comments:gsub(",://", "")
      vim.opt_local.formatoptions:append("r")
      vim.opt_local.formatoptions:remove("o")
      vim.keymap.set("i", "<M-i>", function()
        require("neo.call_parens").to_initializer()
      end, { buffer = true, desc = "new Type() to a collection initializer" })
      vim.keymap.set("i", "<M-CR>", function()
        require("neo.call_parens").finish_statement()
      end, { buffer = true, desc = "Finish the statement: step over closers, add a missing ;" })
    end,
  })

  -- Remove the old command-line Enter mapping on reload, then forward Enter
  -- unchanged for every command except an exact `:q`.
  pcall(vim.keymap.del, "c", "<CR>")
  vim.keymap.set("c", "<CR>", function()
    if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "q" then
      vim.schedule(function()
        local saved, err = pcall(vim.cmd, "wall")
        if saved then
          vim.cmd("q")
        else
          -- Without this the quit silently does nothing, e.g. on an unnamed modified buffer.
          vim.notify("Not quitting: " .. tostring(err):gsub("^.-(E%d+)", "%1"), vim.log.levels.ERROR)
        end
      end)
      return vim.api.nvim_replace_termcodes("<C-c>", true, false, true)
    end
    return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  end, { expr = true, replace_keycodes = false, desc = "Save all before quit" })
end

return M
