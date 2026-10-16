local M = {}

function M.setup()
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
