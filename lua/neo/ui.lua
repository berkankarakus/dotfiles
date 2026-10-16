local M = {}

-- A command that prints nothing leaves its typed text on the command line until something
-- redraws it, and <C-l> (the usual redraw key) is window navigation here. So clear it after a
-- short delay, unless the command raised an error or a newer command has taken over.
M.clear_delay_ms = 3000
M.defer = vim.defer_fn
M.clear_message = function() vim.cmd("echo ''") end

local generation = 0

function M.schedule_message_clear()
  generation = generation + 1
  local mine = generation
  -- CmdlineLeave fires before the command runs, so any change to errmsg is the command's error.
  local errmsg_before = vim.v.errmsg
  M.defer(function()
    if mine ~= generation then return end
    if vim.api.nvim_get_mode().mode ~= "n" then return end
    if vim.v.errmsg ~= errmsg_before then return end
    M.clear_message()
  end, M.clear_delay_ms)
end

function M.setup()
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = vim.api.nvim_create_augroup("ClearCommandLine", { clear = true }),
    callback = function()
      local event = vim.v.event
      if event.cmdtype ~= ":" or event.abort then return end
      M.schedule_message_clear()
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
      vim.wo.colorcolumn = ""
      local winhighlight = vim.wo.winhighlight
      vim.wo.winhighlight = winhighlight == "" and "Cursor:CursorLine" or winhighlight .. ",Cursor:CursorLine"
      use_tree_cursor()
      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { buffer = event.buf, callback = use_tree_cursor })
      vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { buffer = event.buf, callback = use_default_cursor })
    end,
  })
end

return M
