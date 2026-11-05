local M = {}
local signature = require("neo.call_parens.signature")
local initializers = require("neo.call_parens.initializers")
local statement = require("neo.call_parens.statement")

local Kind = { Method = 2, Function = 3, Class = 7, Struct = 22, Keyword = 14 }

-- C# keywords that are always followed by parentheses. `default` and `checked` are
-- left out on purpose: they are valid without them (`default` literal, `checked { }`).
local CSHARP_KEYWORDS = { new = true, typeof = true, nameof = true, sizeof = true }
-- `new()` is the only one that holds across languages (`typeof x` is valid JavaScript).
local NEW_KEYWORD = { new = true }

-- Completion handlers stay here; signatureHelp parsing is isolated in a testable module.
M.request = signature.request
M.plan = signature.plan

-- Built-in types that start an array creation (`new int[]`) when confirmed after `new`.
local PREDEFINED_TYPES = {}
for _, name in ipairs({ "bool", "byte", "sbyte", "char", "decimal", "double", "float", "int", "uint", "long", "ulong", "short", "ushort", "object", "string" }) do
  PREDEFINED_TYPES[name] = true
end

local function is_call_item(kind, before_cursor)
  if kind == Kind.Method or kind == Kind.Function then return true end
  if kind == Kind.Class or kind == Kind.Struct then
    return before_cursor:match("%f[%w_]new%s+[%w_%.]+$") ~= nil
  end
  return false
end

-- Inserts "()" after a confirmed keyword completion, cursor inside. Returns true when
-- the completion was a keyword, whether or not parentheses were added.
local function handle_keyword(item, keywords, buf, row, column, line)
  if item.kind ~= Kind.Keyword then return false end
  local before_cursor = line:sub(1, column)
  if keywords[item.label] and before_cursor:match("%f[%w_]" .. item.label .. "$") then
    vim.api.nvim_buf_set_text(buf, row - 1, column, row - 1, column, { "()" })
    vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  end
  return true
end

-- `new` gets "()" with the cursor inside in any filetype.
function M.handle_new(event)
  if event.commit_character then return end
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  if line:sub(column + 1, column + 1) == "(" then return end
  handle_keyword(event.entry:get_completion_item(), NEW_KEYWORD, vim.api.nvim_get_current_buf(), row, column, line)
end

-- Inserts "[]" with the cursor inside after a built-in type confirmed behind `new`.
local function handle_array(item, buf, row, column, before_cursor)
  if item.kind ~= Kind.Keyword or not PREDEFINED_TYPES[item.label] then return false end
  if not before_cursor:match("%f[%w_]new%s+" .. item.label .. "$") then return false end
  vim.api.nvim_buf_set_text(buf, row - 1, column, row - 1, column, { "[]" })
  vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  return true
end

-- Typing ">" right before the ">" inserted for a generic type steps over it (and adds "()"
-- after `new`). Armed once per completion and dropped on leaving insert mode or the line.
local function arm_generic_close(buf, row, inner_start, add_parens)
  local group = vim.api.nvim_create_augroup("neo_call_parens_generic", { clear = true })
  local function disarm()
    pcall(vim.keymap.del, "i", ">", { buffer = buf })
    vim.api.nvim_clear_autocmds({ group = group })
  end
  vim.keymap.set("i", ">", function()
    local current_row, current_column = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local inner = line:sub(inner_start + 1, current_column)
    local _, opened = inner:gsub("<", "")
    local _, closed = inner:gsub(">", "")
    if current_row ~= row or line:sub(current_column + 1, current_column + 1) ~= ">" or opened ~= closed then return ">" end
    disarm()
    if add_parens and line:sub(current_column + 2, current_column + 2) ~= "(" then return "<Right>()<Left>" end
    return "<Right>"
  end, { buffer = buf, expr = true, replace_keycodes = true })
  vim.api.nvim_create_autocmd({ "InsertLeave", "CursorMovedI" }, {
    group = group,
    buffer = buf,
    callback = function(event)
      if event.event == "InsertLeave" or vim.api.nvim_win_get_cursor(0)[1] ~= row then disarm() end
    end,
  })
end

-- Generic types (`List<T>`) get "<>" with the cursor inside instead of "()".
local function handle_generic(item, buf, row, column, before_cursor)
  if item.kind ~= Kind.Class and item.kind ~= Kind.Struct then return false end
  local name = (item.label or ""):match("^([%w_]+)<")
  if not name or not before_cursor:match("%f[%w_]" .. name .. "$") then return false end
  vim.api.nvim_buf_set_text(buf, row - 1, column, row - 1, column, { "<>" })
  vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  arm_generic_close(buf, row, column + 1, before_cursor:match("%f[%w_]new%s+[%w_%.]+$") ~= nil)
  return true
end

-- Applies the plan once the language server answered, provided nothing changed meanwhile.
local function apply_plan(buf, row, column, plan)
  local line = vim.api.nvim_get_current_line()
  if line:sub(column + 1, column + 2) ~= "()" then return end
  local close = column + 2
  if plan.inside ~= "" then
    vim.api.nvim_buf_set_text(buf, row - 1, column + 1, row - 1, column + 1, { plan.inside })
    close = close + #plan.inside
  end
  if plan.past_close then
    vim.api.nvim_win_set_cursor(0, { row, close })
  elseif plan.inside ~= "" then
    vim.api.nvim_win_set_cursor(0, { row, close - 1 - plan.back })
  end
end

-- Generic types that take exactly one type argument; once it is chosen the closing ">" is next.
local SINGLE_ARGUMENT_GENERICS = {}
for _, name in ipairs({
  "List", "HashSet", "SortedSet", "Queue", "Stack", "LinkedList", "Collection", "ObservableCollection",
  "IEnumerable", "IEnumerator", "IAsyncEnumerable", "ICollection", "IList", "ISet", "IReadOnlyList",
  "IReadOnlyCollection", "IReadOnlySet", "Task", "ValueTask", "Lazy", "Nullable", "Span", "ReadOnlySpan",
  "Memory", "ReadOnlyMemory", "ImmutableArray", "ImmutableList", "ImmutableHashSet", "IComparer",
  "IEqualityComparer", "IComparable", "IEquatable", "Comparer", "EqualityComparer",
}) do
  SINGLE_ARGUMENT_GENERICS[name] = true
end

-- Completion kinds that name a type (LSP: Class, Interface, Enum, Keyword, Struct, TypeParameter).
local TYPE_KINDS = { [7] = true, [8] = true, [13] = true, [14] = true, [22] = true, [25] = true }

-- The generic type whose "<...>" the cursor sits in, when only a single, unfinished argument precedes it.
local function enclosing_generic(before_cursor)
  local depth = 0
  for index = #before_cursor, 1, -1 do
    local character = before_cursor:sub(index, index)
    if character == ">" then
      depth = depth + 1
    elseif character == "<" then
      if depth == 0 then return before_cursor:sub(1, index - 1):match("([%w_]+)%s*$") end
      depth = depth - 1
    elseif character == "," and depth == 0 then
      return nil
    elseif not character:match("[%w_%.%?%[%] ]") then
      return nil
    end
  end
  return nil
end

-- After confirming the one thing a pair of brackets holds, the cursor moves past the closer:
-- `HashSet<int|>` -> `HashSet<int> |`, `typeof(Foo|)` -> `typeof(Foo)|`. `nameof` also takes methods and
-- properties, which must not get "()". Returns true when the completion was handled here.
local function leave_closer(item, row, column, before_cursor, after_cursor)
  local closer = after_cursor:sub(1, 1)
  if closer ~= ">" and closer ~= ")" then return false end
  if (item.label or ""):find("<", 1, true) then return false end

  local applies = false
  if closer == ">" then
    local name = enclosing_generic(before_cursor)
    applies = name ~= nil and SINGLE_ARGUMENT_GENERICS[name] == true and TYPE_KINDS[item.kind] == true
  else
    local operator = before_cursor:match("%f[%w_](%a+)%s*%(%s*[%w_%.%?%[%] ]*$")
    if operator == "nameof" then
      applies = true
    elseif operator == "typeof" or operator == "sizeof" or operator == "default" then
      applies = TYPE_KINDS[item.kind] == true
    end
  end
  if not applies then return false end
  if closer == ">" then
    -- A type that ends a declaration (`List<int>` before its variable name) gets a space after it;
    -- a following "(", ";" or similar stays directly attached.
    local rest = after_cursor:sub(2)
    if rest == "" then
      vim.api.nvim_buf_set_text(0, row - 1, column + 1, row - 1, column + 1, { " " })
      vim.api.nvim_win_set_cursor(0, { row, column + 2 })
    elseif rest:sub(1, 1) == " " then
      vim.api.nvim_win_set_cursor(0, { row, column + 2 })
    else
      vim.api.nvim_win_set_cursor(0, { row, column + 1 })
    end
    return true
  end
  vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  return true
end

local function completion_context()
  local buf = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  return {
    buf = buf,
    row = row,
    column = column,
    line = line,
    before_cursor = line:sub(1, column),
    after_cursor = line:sub(column + 1),
  }
end

local function request_call_plan(context)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(context.buf),
    position = {
      line = context.row - 1,
      character = vim.str_utfindex(context.line, "utf-16", context.column) + 1,
    },
    context = { triggerKind = 2, triggerCharacter = "(", isRetrigger = false },
  }
  local tick = vim.api.nvim_buf_get_changedtick(context.buf)
  M.request(context.buf, params, function(help)
    local plan = M.plan(help)
    if not plan then return end
    if vim.api.nvim_get_current_buf() ~= context.buf or vim.api.nvim_buf_get_changedtick(context.buf) ~= tick then return end
    local current_row, current_column = unpack(vim.api.nvim_win_get_cursor(0))
    if current_row ~= context.row or current_column ~= context.column + 1 then return end
    apply_plan(context.buf, context.row, context.column, plan)
  end)
end

-- Inserts "()" after a confirmed C# method/constructor completion with the cursor
-- inside, then asks the language server what the call takes: a parameterless call moves the
-- cursor past ")" and a first argument of a known type gets a placeholder (`''`, `x => `). The
-- statement's ";" is left to Option-Enter. Keywords such as `new` and `typeof` keep the cursor
-- inside, built-in types behind `new` get "[]" and generic types get "<>".
function M.handle(event)
  if event.commit_character then return end

  local item = event.entry:get_completion_item()
  local context = completion_context()
  local next_character = context.after_cursor:sub(1, 1)
  if leave_closer(item, context.row, context.column, context.before_cursor, context.after_cursor) then return end
  if next_character == "(" or next_character == "[" or next_character == "<" then return end
  if handle_array(item, context.buf, context.row, context.column, context.before_cursor) then return end
  if handle_keyword(item, CSHARP_KEYWORDS, context.buf, context.row, context.column, context.line) then return end
  if handle_generic(item, context.buf, context.row, context.column, context.before_cursor) then return end

  if not is_call_item(item.kind, context.before_cursor) then return end

  vim.api.nvim_buf_set_text(context.buf, context.row - 1, context.column, context.row - 1, context.column, { "()" })
  vim.api.nvim_win_set_cursor(0, { context.row, context.column + 1 })
  request_call_plan(context)
end

M.to_initializer = initializers.to_initializer
M.to_collection_expression = initializers.to_collection_expression
M.finish_statement = statement.finish_statement

return M
