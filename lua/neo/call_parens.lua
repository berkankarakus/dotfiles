local M = {}

local Kind = { Method = 2, Function = 3, Class = 7, Struct = 22, Keyword = 14 }

-- C# keywords that are always followed by parentheses. `default` and `checked` are
-- left out on purpose: they are valid without them (`default` literal, `checked { }`).
local CSHARP_KEYWORDS = { new = true, typeof = true, nameof = true, sizeof = true }
-- `new()` is the only one that holds across languages (`typeof x` is valid JavaScript).
local NEW_KEYWORD = { new = true }

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

-- Built-in types that start an array creation (`new int[]`) when confirmed after `new`.
local PREDEFINED_TYPES = {}
for _, name in ipairs({ "bool", "byte", "sbyte", "char", "decimal", "double", "float", "int", "uint", "long", "ulong", "short", "ushort", "object", "string" }) do
  PREDEFINED_TYPES[name] = true
end

-- Delegate types whose argument is usually a lambda, and how many lambda parameters they take
-- from their type arguments (nil means "all but the last", as for Func).
local LAMBDA_TYPES = {
  Func = function(count) return count - 1 end,
  Action = function(count) return count end,
  Predicate = function() return 1 end,
  Comparison = function() return 2 end,
  Converter = function() return 1 end,
}

local function split_top_level(text)
  local parts, depth, start = {}, 0, 1
  for index = 1, #text do
    local char = text:sub(index, index)
    if char == "<" or char == "(" or char == "[" then
      depth = depth + 1
    elseif char == ">" or char == ")" or char == "]" then
      depth = depth - 1
    elseif char == "," and depth == 0 then
      table.insert(parts, vim.trim(text:sub(start, index - 1)))
      start = index + 1
    end
  end
  local last = vim.trim(text:sub(start))
  if last ~= "" then table.insert(parts, last) end
  return parts
end

local function lambda_head(count)
  if count == 1 then return "x => " end
  if count == 0 then return "() => " end
  local names = {}
  for index = 1, count do names[index] = string.char(96 + index) end
  return "(" .. table.concat(names, ", ") .. ") => "
end

-- Text to pre-fill inside the parentheses for a parameter type, and how far back from its end
-- the cursor belongs. Returns nil for types without a sensible placeholder.
local function template_for(parameter_type)
  parameter_type = parameter_type:gsub("%?$", ""):gsub("^System%.", "")
  if parameter_type == "string" then return '""', 1 end
  if parameter_type == "char" then return "''", 1 end
  local name, arguments = parameter_type:match("^([%w_]+)<(.*)>$")
  name = name or parameter_type
  local parameter_count = LAMBDA_TYPES[name]
  if not parameter_count then return nil end
  local count = parameter_count(arguments and #split_top_level(arguments) or 0)
  if count < 0 then return nil end
  return lambda_head(count), 0
end

-- Roslyn labels a parameter with its name only; the type sits in the signature label,
-- "void Foo.Say(string message)" or "(extension) T X.Where<T>(Func<T, bool> predicate)".
local function parameter_declaration(signature, index, parameter)
  local text = (signature.label or ""):gsub("^%(extension%)%s*", "")
  local inside = text:match("%((.*)%)%s*$")
  local declaration = inside and split_top_level(inside)[index]
  if declaration then return declaration end
  local label = parameter.label
  if type(label) == "table" then label = signature.label and signature.label:sub(label[1] + 1, label[2]) end
  return type(label) == "string" and label or nil
end

-- The type of a parameter label such as "Func<int, bool> predicate" or "string name = null".
local function parameter_type_of(label)
  label = label:gsub("%s*=.*$", "")
  local modifier = label:match("^%s*(%l+)%s")
  if modifier == "params" or modifier == "ref" or modifier == "out" or modifier == "in" or modifier == "this" then return nil end
  return label:match("^%s*(.-)%s+[%w_@]+%s*$")
end

-- A placeholder for the first argument, but only when every overload agrees on its type and
-- none is parameterless.
local function argument_template(help)
  local agreed
  for _, signature in ipairs(help.signatures) do
    local first = signature.parameters and signature.parameters[1]
    if not first then return nil end
    local label = parameter_declaration(signature, 1, first)
    local parameter_type = label and parameter_type_of(label)
    if not parameter_type or (agreed and agreed ~= parameter_type) then return nil end
    agreed = parameter_type
  end
  if not agreed then return nil end
  return template_for(agreed)
end

local function returns_void(help)
  for _, signature in ipairs(help.signatures) do
    if not (signature.label or ""):gsub("^%(extension%)%s*", ""):match("^void%s") then return false end
  end
  return true
end

-- A statement-position call such as `list.Clear` on its own line, with nothing after it.
local function is_statement(before_cursor, after_cursor)
  return before_cursor:match("^%s*[%w_%.%?!]+$") ~= nil and after_cursor:match("^%s*$") ~= nil
end

-- What to add once the language server has answered: text inside the parentheses, a trailing
-- ";" for void calls in statement position, and where the cursor ends up.
function M.plan(help, before_cursor, after_cursor)
  if not help or not help.signatures or #help.signatures == 0 then return nil end
  local plan = { inside = "", back = 0, semicolon = false, past_close = takes_no_arguments(help) }
  if not plan.past_close then
    local inside, back = argument_template(help)
    plan.inside, plan.back = inside or "", back or 0
  end
  plan.semicolon = returns_void(help) and is_statement(before_cursor, after_cursor)
  return plan
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
  if plan.semicolon then vim.api.nvim_buf_set_text(buf, row - 1, close, row - 1, close, { ";" }) end
  if plan.past_close then
    vim.api.nvim_win_set_cursor(0, { row, close + (plan.semicolon and 1 or 0) })
  elseif plan.inside ~= "" then
    vim.api.nvim_win_set_cursor(0, { row, close - 1 - plan.back })
  end
end

-- Inserts "()" after a confirmed C# method/constructor completion with the cursor
-- inside, then asks the language server what the call takes: a parameterless call moves the
-- cursor past ")", a first argument of a known type gets a placeholder (`""`, `''`, `x => `),
-- and a void call in statement position gets its ";". Keywords such as `new` and `typeof`
-- keep the cursor inside, built-in types behind `new` get "[]" and generic types get "<>".
function M.handle(event)
  if event.commit_character then return end

  local item = event.entry:get_completion_item()
  local buf = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before_cursor = line:sub(1, column)
  local after_cursor = line:sub(column + 1)
  local next_character = after_cursor:sub(1, 1)
  if next_character == "(" or next_character == "[" or next_character == "<" then return end
  if handle_array(item, buf, row, column, before_cursor) then return end
  if handle_keyword(item, CSHARP_KEYWORDS, buf, row, column, line) then return end
  if handle_generic(item, buf, row, column, before_cursor) then return end

  if not is_call_item(item.kind, before_cursor) then return end

  vim.api.nvim_buf_set_text(buf, row - 1, column, row - 1, column, { "()" })
  vim.api.nvim_win_set_cursor(0, { row, column + 1 })
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  local params = {
    textDocument = vim.lsp.util.make_text_document_params(buf),
    position = { line = row - 1, character = vim.str_utfindex(line, "utf-16", column) + 1 },
    context = { triggerKind = 2, triggerCharacter = "(", isRetrigger = false },
  }
  M.request(buf, params, function(help)
    local plan = M.plan(help, before_cursor, after_cursor)
    if not plan then return end
    if vim.api.nvim_get_current_buf() ~= buf or vim.api.nvim_buf_get_changedtick(buf) ~= tick then return end
    local current_row, current_column = unpack(vim.api.nvim_win_get_cursor(0))
    if current_row ~= row or current_column ~= column + 1 then return end
    apply_plan(buf, row, column, plan)
  end)
end

-- Turns the `()` of a `new Type()` into a collection initializer, ` { | }`, or appends one
-- to an array creation (`new int[3]`). Works with the cursor inside or right after the `()`.
-- Returns false when the cursor is not at such an expression.
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
  if not line:sub(1, start):match(type_expression) and start ~= finish then return false end
  if after:sub(1, 1) == "{" then return false end
  vim.api.nvim_buf_set_text(0, row - 1, start, row - 1, finish, { " {  }" })
  vim.api.nvim_win_set_cursor(0, { row, start + 3 })
  return true
end

return M
