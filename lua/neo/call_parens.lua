local M = {}

local Kind = { Method = 2, Function = 3, Class = 7, Struct = 22 }

function M.request(buf, params, callback)
  vim.lsp.buf_request(buf, "textDocument/signatureHelp", params, function(err, result)
    callback(not err and result or nil)
  end)
end

local function takes_no_arguments(help)
  if not help or not help.signatures or #help.signatures == 0 then return false end
  for _, signature in ipairs(help.signatures) do
    if signature.parameters and #signature.parameters > 0 then return false end
  end
  return true
end

local function is_call_item(kind, before_cursor)
  if kind == Kind.Method or kind == Kind.Function then return true end
  if kind == Kind.Class or kind == Kind.Struct then
    return before_cursor:match("%f[%w_]new%s+[%w_%.]+$") ~= nil
  end
  return false
end

-- Inserts "()" after a confirmed C# method/constructor completion with the cursor
-- inside, then moves it past ")" once the language server reports that every
-- overload is parameterless.
function M.handle(event)
  if event.commit_character then return end

  local item = event.entry:get_completion_item()
  local buf = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  if not is_call_item(item.kind, line:sub(1, column)) then return end
  if line:sub(column + 1, column + 1) == "(" then return end

  vim.api.nvim_buf_set_text(buf, row - 1, column, row - 1, column, { "()" })
  vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  local params = {
    textDocument = vim.lsp.util.make_text_document_params(buf),
    position = { line = row - 1, character = vim.str_utfindex(line, "utf-16", column) + 1 },
    context = { triggerKind = 2, triggerCharacter = "(", isRetrigger = false },
  }
  M.request(buf, params, function(help)
    if not takes_no_arguments(help) then return end
    if vim.api.nvim_get_current_buf() ~= buf or vim.api.nvim_buf_get_changedtick(buf) ~= tick then return end
    local current_row, current_column = unpack(vim.api.nvim_win_get_cursor(0))
    if current_row ~= row or current_column ~= column + 1 then return end
    vim.api.nvim_win_set_cursor(0, { row, column + 2 })
  end)
end

return M
