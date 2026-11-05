local M = {}

local namespace = vim.api.nvim_create_namespace("neo-virt-column-tail")
local column = 120

local function refresh()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

      if buftype == "" and filetype ~= "NvimTree" then
        local line_count = vim.api.nvim_buf_line_count(buf)
        local first = math.max(0, line_count - 3)
        -- Clear the whole namespace so marks that fell out of the trailing window
        -- cannot remain when the buffer grows or shrinks.
        vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

        local leftcol = vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol or 0
        for row = first, line_count - 1 do
          local width = vim.api.nvim_win_call(win, function()
            return vim.fn.virtcol({ row + 1, "$" }) - 1
          end)

          if width < column then
            vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
              virt_text = { { "┊", "VirtColumn" } },
              virt_text_pos = "overlay",
              virt_text_win_col = column - 1 - leftcol,
              hl_mode = "combine",
              priority = 1,
            })
          end
        end
      end
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NeoVirtColumnTail", { clear = true })
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "BufWinEnter",
    "TextChanged",
    "TextChangedI",
    "WinEnter",
    "WinScrolled",
    "WinResized",
  }, {
    group = group,
    callback = refresh,
  })
  refresh()
end

return M
