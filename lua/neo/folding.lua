local M = {}

local function set_window_folding(win)
  vim.wo[win].foldmethod = "expr"
  vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.wo[win].foldlevel = 99
  vim.wo[win].foldenable = true
end

function M.enable(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return false end
  local filetype = vim.bo[buf].filetype
  if filetype == "" then return false end

  local language = vim.treesitter.language.get_lang(filetype) or filetype
  local ok, query = pcall(vim.treesitter.query.get, language, "folds")
  if not ok or not query then return false end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do set_window_folding(win) end
  return true
end

function M.setup()
  vim.o.foldcolumn = "1"
  vim.o.foldlevel = 99
  vim.o.foldlevelstart = 99
  vim.o.foldenable = true

  local group = vim.api.nvim_create_augroup("NeoTreesitterFolding", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = group,
    callback = function(event)
      if not M.enable(event.buf) then vim.schedule(function() M.enable(event.buf) end) end
    end,
  })
end

return M
