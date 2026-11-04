local M = {}

-- Turns the `()` of a `new Type()` into a collection initializer, ` { | }`, or appends one
-- to an array creation (`new int[3]`). Works with the cursor inside or right after the `()`.
function M.to_initializer()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before, after = line:sub(1, column), line:sub(column + 1)
  local type_expression = "%f[%w_]new%s+[%w_%.<>, %[%]]+$"
  local start, finish
  if before:sub(-1) == "(" and after:sub(1, 1) == ")" then
    start, finish = column - 1, column + 1
  elseif before:sub(-2) == "()" then
    start, finish = column - 2, column
  elseif before:match("%f[%w_]new%s+[%w_%.<>, ]+%[[^%]]*%]$") then
    start, finish = column, column
  else
    return false
  end
  local target_typed = line:sub(1, start):match("%f[%w_]new%s*$") ~= nil
  if not line:sub(1, start):match(type_expression) and not target_typed and start ~= finish then return false end
  if after:sub(1, 1) == "{" then return false end
  -- `new()` is complete as it is (`new() { }`), whereas `new List<int>()` loses its "()".
  if target_typed then start = finish end
  vim.api.nvim_buf_set_text(0, row - 1, start, row - 1, finish, { " {  }" })
  vim.api.nvim_win_set_cursor(0, { row, start + 3 })
  return true
end

local COLLECTION_TYPES = { List = true, HashSet = true, SortedSet = true, Collection = true, ObservableCollection = true }
local COLLECTION_TARGETS = {
  List = true, HashSet = true, SortedSet = true, Collection = true, ObservableCollection = true,
  IEnumerable = true, ICollection = true, IList = true, IReadOnlyCollection = true, IReadOnlyList = true,
  ISet = true, Span = true, ReadOnlySpan = true, ImmutableArray = true,
}
local DECLARATION_MODIFIERS = {
  public = true, private = true, protected = true, internal = true, static = true, readonly = true,
  volatile = true, new = true, partial = true, required = true, unsafe = true,
}

local function declaration_without_initializer(before, after)
  if not after:match("^%s*;?%s*$") then return false end
  local head, name = before:match("^%s*(.-)%s+([%a_@][%w_@]*)$")
  if not head then return false end
  local type_text = head
  while true do
    local word, rest = type_text:match("^(%a+)%s+(.+)$")
    if word and DECLARATION_MODIFIERS[word] then type_text = rest else break end
  end
  local is_array = type_text:match("^[%w_%.]+%[%]%??$") ~= nil
  local generic = type_text:match("^[%w_%.]-([%w_]+)%b<>%??$")
  if not is_array and not (generic and COLLECTION_TARGETS[generic]) then return false end
  return name ~= "in" and name ~= "is" and name ~= "as"
end

function M.to_collection_expression()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before, after = line:sub(1, column), line:sub(column + 1)
  if declaration_without_initializer(before, after) then
    vim.api.nvim_buf_set_text(0, row - 1, column, row - 1, column, { " = []" })
    vim.api.nvim_win_set_cursor(0, { row, column + 4 })
    return true
  end
  local finish
  if before:sub(-1) == "(" and after:sub(1, 1) == ")" then
    finish = column + 1
  elseif before:sub(-2) == "()" then
    finish = column
  else
    return false
  end
  local prefix, type_text = line:sub(1, finish - 2):match("^(.*)%f[%w_]new%s*([%w_%.<>, %[%]]-)%s*$")
  if not prefix then return false end
  if line:sub(finish + 1):match("^%s*{") then return false end

  local assigned = prefix:match("=%s*$") and not prefix:match("[=!<>]=%s*$") and not prefix:match("=>%s*$")
  local returned = prefix:match("%f[%w_]return%s+$")
  if not assigned and not returned then return false end
  if prefix:match("%f[%w_]var%s+[%w_]+%s*=%s*$") then return false end
  if type_text ~= "" then
    local name = type_text:match("([%w_]+)<")
    if not name or not COLLECTION_TYPES[name] then return false end
  end

  vim.api.nvim_buf_set_text(0, row - 1, #prefix, row - 1, finish, { "[]" })
  vim.api.nvim_win_set_cursor(0, { row, #prefix + 1 })
  return true
end

return M
