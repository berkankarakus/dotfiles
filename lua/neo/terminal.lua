local M = {}

function M.setup()
  local terminal_buf
  local function show_terminal()
    if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
      for _, window in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(window) == terminal_buf then return end
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
end

return M
