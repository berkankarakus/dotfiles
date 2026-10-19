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
  local target_typed = line:sub(1, start):match("%f[%w_]new%s*$") ~= nil
  if not line:sub(1, start):match(type_expression) and not target_typed and start ~= finish then return false end
  if after:sub(1, 1) == "{" then return false end
  -- `new()` is complete as it is (`new() { }`), whereas `new List<int>()` loses its "()".
  if target_typed then start = finish end
  vim.api.nvim_buf_set_text(0, row - 1, start, row - 1, finish, { " {  }" })
  vim.api.nvim_win_set_cursor(0, { row, start + 3 })
  return true
end

-- Statements and declarations that end in ";". A missing ";" under anything else, such as the
-- empty statement the parser invents after `if (x)`, is not a semicolon the user forgot.
local SEMICOLON_PARENTS = {
  expression_statement = true,
  local_declaration_statement = true,
  return_statement = true,
  throw_statement = true,
  break_statement = true,
  continue_statement = true,
  yield_statement = true,
  goto_statement = true,
  do_statement = true,
  field_declaration = true,
  event_field_declaration = true,
  using_directive = true,
  delegate_declaration = true,
}

-- Collection types a C# 12 collection expression (`[1, 2]`) can create through their Add method.
local COLLECTION_TYPES = { List = true, HashSet = true, SortedSet = true, Collection = true, ObservableCollection = true }

-- Types a collection expression can initialize besides arrays: collection classes with an Add
-- method, spans, immutable arrays and the collection interfaces.
local COLLECTION_TARGETS = {
  List = true, HashSet = true, SortedSet = true, Collection = true, ObservableCollection = true,
  IEnumerable = true, ICollection = true, IList = true, IReadOnlyCollection = true, IReadOnlyList = true,
  ISet = true, Span = true, ReadOnlySpan = true, ImmutableArray = true,
}

local DECLARATION_MODIFIERS = {
  public = true, private = true, protected = true, internal = true, static = true, readonly = true,
  volatile = true, new = true, partial = true, required = true, unsafe = true,
}

-- `List<int> m|` (cursor right after the name, only an optional ";" behind it) becomes
-- `List<int> m = [|]`. The type has to be written out and be one a collection expression can create.
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

-- Replaces `new()` or `new List<int>()` with an empty collection expression, `[|]`, when the
-- target type is known from the left-hand side. `var x = new List<int>()` is refused because
-- `var x = []` has no type to infer. Works with the cursor inside or right after the `()`.
-- Returns false when the cursor is not at such an expression.
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

-- Collects the MISSING and ERROR nodes that touch a row.
local function row_findings(node, row, found)
  local start_row, _, end_row = node:range()
  if row < start_row or row > end_row then return end
  if node:type() == "ERROR" then table.insert(found.errors, node) end
  if node:missing() then
    if start_row == row then table.insert(found.missing, node) end
    return
  end
  for child in node:iter_children() do row_findings(child, row, found) end
end

local function last_real_end(node)
  local last
  for child in node:iter_children() do
    if child:type() ~= "comment" then last = child end
  end
  if last and last:child_count() > 0 then return last_real_end(last) end
  return (last or node):end_()
end

local function has_error_on(node, row)
  local start_row, _, end_row = node:range()
  if row < start_row or row > end_row then return false end
  if node:type() == "ERROR" or node:missing() then return true end
  for child in node:iter_children() do
    if has_error_on(child, row) then return true end
  end
  return false
end

-- Declarations that take a ";" only after an initializer or an expression body, e.g.
-- `public int X { get; set; } = 1` or `int P => f()`. Without one, `void M()` plus ";" would
-- turn a method header into an abstract declaration.
local EXPRESSION_BODIED = {
  property_declaration = true,
  method_declaration = true,
  indexer_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
}

local function ends_a_statement(parent)
  if SEMICOLON_PARENTS[parent:type()] then return true end
  if not EXPRESSION_BODIED[parent:type()] then return false end
  if #parent:field("value") > 0 then return true end
  for child in parent:iter_children() do
    if child:type() == "arrow_expression_clause" or child:type() == "equals_value_clause" then return true end
  end
  return false
end

-- Members whose text parses on its own; the check reparses only the one around the cursor.
local MEMBER_TYPES = {
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  accessor_declaration = true,
  local_function_statement = true,
  property_declaration = true,
  indexer_declaration = true,
  field_declaration = true,
  event_field_declaration = true,
  event_declaration = true,
  delegate_declaration = true,
}

-- The range of the member around a position, or nil to parse the whole file.
local function member_range(root, row, column)
  local node = root:descendant_for_range(row, column, row, column)
  while node and not MEMBER_TYPES[node:type()] do node = node:parent() end
  if not node then return nil end
  local start_row, start_column, end_row, end_column = node:range()
  return { start_row, start_column, end_row, end_column }
end

-- Whether adding ";" at the position makes the row parse cleanly with the ";" ending a real
-- statement. Tried in a scratch buffer, so a wrong guess never touches the file, and only the
-- member around the position is parsed, so the cost does not grow with the file.
local function semicolon_fits(lines, row, column, range)
  local scratch = vim.api.nvim_create_buf(false, true)
  local fits = false
  pcall(function()
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
    vim.api.nvim_buf_set_text(scratch, row, column, row, column, { ";" })
    local parser = vim.treesitter.get_parser(scratch, "c_sharp")
    if range then
      -- The inserted ";" widens the member by one column only when it ends on the same row.
      if range[3] == row then range[4] = range[4] + 1 end
      parser:set_included_regions({ { range } })
    end
    local root = parser:parse(true)[1]:root()
    local token = root:descendant_for_range(row, column, row, column + 1)
    fits = not has_error_on(root, row) and token ~= nil and token:type() == ";"
      and token:parent() ~= nil and ends_a_statement(token:parent())
  end)
  vim.api.nvim_buf_delete(scratch, { force = true })
  return fits
end

-- Finishes the statement under the cursor: steps over the `)` / `]` that follow it, then adds
-- a ";" where one is missing. The spot comes from the parse tree and the result is checked
-- in a scratch copy first, so an unfinished or ambiguous row (an unclosed bracket, an
-- `if (x)` header) is left alone instead of guessed at.
-- Returns true when the buffer or the cursor changed.
function M.finish_statement()
  local buf = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local closers = #line:sub(column + 1):match("^[%)%]]*")
  local changed = closers > 0
  if changed then
    column = column + closers
    vim.api.nvim_win_set_cursor(0, { row, column })
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "c_sharp")
  if not ok or not parser then return changed end
  local root = parser:parse(true)[1]:root()
  local found = { missing = {}, errors = {} }
  row_findings(root, row - 1, found)

  local semicolon_column
  if #found.missing == 1 and #found.errors == 0 and found.missing[1]:type() == ";" then
    local previous = found.missing[1]:prev_sibling()
    while previous and previous:type() == "comment" do previous = previous:prev_sibling() end
    if previous then
      local previous_row, previous_column = previous:end_()
      if previous_row == row - 1 then semicolon_column = previous_column end
    end
  elseif #found.missing == 0 and #found.errors == 1 then
    local error_row, error_column = last_real_end(found.errors[1])
    if error_row == row - 1 then semicolon_column = error_column end
  end
  if not semicolon_column then return changed end
  local range = member_range(root, row - 1, semicolon_column)
  if not semicolon_fits(vim.api.nvim_buf_get_lines(buf, 0, -1, false), row - 1, semicolon_column, range) then
    return changed
  end

  vim.api.nvim_buf_set_text(buf, row - 1, semicolon_column, row - 1, semicolon_column, { ";" })
  vim.api.nvim_win_set_cursor(0, { row, math.max(column, semicolon_column + 1) })
  return true
end

return M
