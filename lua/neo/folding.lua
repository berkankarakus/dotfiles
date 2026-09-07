local M = {}

local csharp_fold_cache = {}

function M.csharp_foldexpr()
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

function M.setup()
  _G.csharp_foldexpr = M.csharp_foldexpr
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
end

return M
