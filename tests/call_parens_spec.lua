local call_parens = require("neo.call_parens")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local METHOD, CLASS, KEYWORD = 2, 7, 14

local function event(kind, commit_character, label)
  return {
    commit_character = commit_character,
    entry = { get_completion_item = function() return { kind = kind, label = label } end },
  }
end

-- Normal mode cannot park the cursor past the last character, so the line gets a
-- trailing ";" (stripped again in run) to mimic the insert-mode cursor position.
local function setup(line, column)
  if not column then
    column = #line
    line = line .. ";"
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.bo.filetype = "cs"
  vim.api.nvim_win_set_cursor(0, { 1, column })
end

local pending
call_parens.request = function(_, params, callback)
  pending = { params = params, callback = callback }
end

local function run(kind, line, help, column)
  pending = nil
  setup(line, column)
  call_parens.handle(event(kind))
  if pending and help ~= nil then pending.callback(help) end
  return (vim.api.nvim_get_current_line():gsub(";$", "")), vim.api.nvim_win_get_cursor(0)[2]
end

local function signatures(...)
  local result = {}
  for _, count in ipairs({ ... }) do
    local parameters = {}
    for index = 1, count do parameters[index] = { label = "p" .. index } end
    table.insert(result, { label = "sig", parameters = parameters })
  end
  return { signatures = result }
end

local text, col = run(METHOD, "list.Clear", signatures(0))
assert_equal("list.Clear()", text, "parentheses should be inserted")
assert_equal(#"list.Clear()", col, "parameterless method should move the cursor after )")
assert_equal(#"list.Clear" + 1, pending.params.position.character, "signature help should be requested inside the parentheses")

text, col = run(METHOD, "list.Add", signatures(1))
assert_equal("list.Add()", text, "parentheses should be inserted for methods with arguments")
assert_equal(#"list.Add" + 1, col, "method with arguments should keep the cursor inside")

_, col = run(METHOD, "f.Over", signatures(0, 1))
assert_equal(#"f.Over" + 1, col, "an overload with arguments should keep the cursor inside")

_, col = run(METHOD, "f.Over", signatures(0, 0))
assert_equal(#"f.Over()", col, "all-parameterless overloads should move the cursor after )")

_, col = run(METHOD, "f.Zero", nil)
assert_equal(#"f.Zero" + 1, col, "cursor should stay inside until the server answers")

_, col = run(METHOD, "f.Zero", { signatures = {} })
assert_equal(#"f.Zero" + 1, col, "no signatures should keep the cursor inside")

_, col = run(METHOD, "f.Zero", false)
assert_equal(#"f.Zero" + 1, col, "an unanswered request should keep the cursor inside")

-- A stale answer must not move the cursor after the user kept typing.
setup("f.Zero")
call_parens.handle(event(METHOD))
vim.api.nvim_feedkeys("", "x", false)
vim.api.nvim_buf_set_text(0, 0, #"f.Zero" + 1, 0, #"f.Zero" + 1, { "x" })
vim.api.nvim_win_set_cursor(0, { 1, #"f.Zero" + 2 })
pending.callback(signatures(0))
assert_equal(#"f.Zero" + 2, vim.api.nvim_win_get_cursor(0)[2], "a stale answer should not move the cursor")

text = run(METHOD, "f.Zero(", nil, #"f.Zero")
assert_equal("f.Zero(", text, "existing parentheses should be left alone")

text, col = run(METHOD, "f.Zero", signatures(0))
call_parens.handle({ commit_character = "(", entry = event(METHOD).entry })
assert_equal("f.Zero()", text, "a typed commit character should not trigger insertion")

-- Constructors: only after `new`.
text, col = run(CLASS, "var a = new Foo", signatures(0))
assert_equal("var a = new Foo()", text, "constructor parentheses should be inserted after new")
assert_equal(#"var a = new Foo()", col, "parameterless constructor should move the cursor after )")

_, col = run(CLASS, "var b = new Bar", signatures(1))
assert_equal(#"var b = new Bar" + 1, col, "constructor with arguments should keep the cursor inside")

text = run(CLASS, "Foo", nil)
assert_equal("Foo", text, "a type outside a new expression should not get parentheses")

text = run(1, "foo", nil)
assert_equal("foo", text, "non-call completion kinds should be ignored")

-- Keywords always keep the cursor inside and never ask the server.
local function run_keyword(line, label, column)
  pending = nil
  setup(line, column)
  call_parens.handle(event(KEYWORD, nil, label))
  return (vim.api.nvim_get_current_line():gsub(";$", "")), vim.api.nvim_win_get_cursor(0)[2]
end

for _, keyword in ipairs({ "typeof", "nameof", "sizeof", "new" }) do
  text, col = run_keyword("var x = " .. keyword, keyword)
  assert_equal("var x = " .. keyword .. "()", text, keyword .. " should get parentheses")
  assert_equal(#("var x = " .. keyword) + 1, col, keyword .. " should keep the cursor inside")
  assert_equal(nil, pending, keyword .. " should not query signature help")
end

text = run_keyword("var x = default", "default")
assert_equal("var x = default", text, "default is valid without parentheses")

text = run_keyword("var x = checked", "checked")
assert_equal("var x = checked", text, "checked may open a block instead of a call")

text = run_keyword("var x = typeof(", "typeof", #"var x = typeof")
assert_equal("var x = typeof(", text, "an existing ( after a keyword should be left alone")

text = run_keyword("var x = renew", "new")
assert_equal("var x = renew", text, "a keyword that is only a word suffix should be ignored")

text = run_keyword("var x = typeof", "other")
assert_equal("var x = typeof", text, "keywords outside the list should be ignored")

-- Outside C# only `new` is handled.
local function run_new(line, label)
  setup(line)
  call_parens.handle_new(event(KEYWORD, nil, label))
  return (vim.api.nvim_get_current_line():gsub(";$", "")), vim.api.nvim_win_get_cursor(0)[2]
end

text, col = run_new("x = new", "new")
assert_equal("x = new()", text, "new should get parentheses in any filetype")
assert_equal(#"x = new" + 1, col, "new should keep the cursor inside")

text = run_new("x = typeof", "typeof")
assert_equal("x = typeof", text, "typeof must not get parentheses outside C#")

setup("x = new")
call_parens.handle_new(event(METHOD, nil, "new"))
assert_equal("x = new;", vim.api.nvim_get_current_line(), "handle_new should ignore non-keyword items")

-- Argument placeholders follow the first parameter's type.
local function typed(label, ...)
  local result = { label = "sig" }
  result.parameters = { { label = label } }
  for _, extra in ipairs({ ... }) do table.insert(result.parameters, { label = extra }) end
  return result
end

text, col = run(METHOD, "f.Say", { signatures = { typed("string message") } })
assert_equal('f.Say("")', text, "a string parameter should get quotes")
assert_equal(#'f.Say("', col, "the cursor should sit between the quotes")

text, col = run(METHOD, "f.Pick", { signatures = { typed("char separator = ','", "int count") } })
assert_equal("f.Pick('')", text, "a char parameter should get single quotes")
assert_equal(#"f.Pick('", col, "the cursor should sit between the single quotes")

text, col = run(METHOD, "f.Where", { signatures = { typed("Func<int, bool> predicate") } })
assert_equal("f.Where(x => )", text, "a Func with one input should get a lambda head")
assert_equal(#"f.Where(x => ", col, "the cursor should follow the lambda arrow")

text = run(METHOD, "f.Sort", { signatures = { typed("Comparison<int> comparison") } })
assert_equal("f.Sort((a, b) => )", text, "a Comparison should get two lambda parameters")

text = run(METHOD, "f.Each", { signatures = { typed("Action action") } })
assert_equal("f.Each(() => )", text, "a plain Action should get an empty parameter list")

text = run(METHOD, "f.Fold", { signatures = { typed("Func<int, Dictionary<int, string>, bool> f") } })
assert_equal("f.Fold((a, b) => )", text, "nested generic arguments should count as one")

text = run(METHOD, "f.Find", { signatures = { typed("string? name") } })
assert_equal('f.Find("")', text, "a nullable string should still get quotes")

text = run(METHOD, "f.Num", { signatures = { typed("int value") } })
assert_equal("f.Num()", text, "types without a placeholder should stay empty")

text = run(METHOD, "f.Many", { signatures = { typed("params string[] values") } })
assert_equal("f.Many()", text, "params arrays should stay empty")

text = run(METHOD, "f.Out", { signatures = { typed("out string value") } })
assert_equal("f.Out()", text, "out parameters should stay empty")

text = run(METHOD, "f.Mixed", { signatures = { typed("string a"), typed("int b") } })
assert_equal("f.Mixed()", text, "overloads that disagree should stay empty")

text = run(METHOD, "f.Opt", { signatures = { { label = "sig", parameters = {} }, typed("string a") } })
assert_equal("f.Opt()", text, "a parameterless overload should keep the call empty")

text = run(METHOD, "f.Same", { signatures = { typed("string a"), typed("string b", "int c") } })
assert_equal('f.Same("")', text, "overloads agreeing on the first type should get the placeholder")

local offsets = { label = "void F.G(string name)", parameters = { { label = { 9, 20 } } } }
text = run(METHOD, "f.G", { signatures = { offsets } })
assert_equal('f.G("")', text, "offset labels should be resolved against the signature label")

-- Void calls in statement position get their semicolon. "onemore" lets the cursor sit past
-- the last character, so nothing follows it.
vim.o.virtualedit = "onemore"
local function run_statement(line, help)
  pending = nil
  setup(line, #line)
  call_parens.handle(event(METHOD))
  pending.callback(help)
  return vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2]
end

local function void(label, count)
  local parameters = {}
  for index = 1, count do parameters[index] = { label = "int p" .. index } end
  return { label = label, parameters = parameters }
end

text, col = run_statement("    list.Clear", { signatures = { void("void List<int>.Clear()", 0) } })
assert_equal("    list.Clear();", text, "a void statement should get a semicolon")
assert_equal(#"    list.Clear();", col, "the cursor should end after the semicolon")

text, col = run_statement("    list.Add", { signatures = { void("void List<int>.Add(int p1)", 1) } })
assert_equal("    list.Add();", text, "a void statement with arguments should get a semicolon")
assert_equal(#"    list.Add" + 1, col, "the cursor should stay inside the parentheses")

text = run_statement("    var x = list.Clear", { signatures = { void("void L.Clear()", 0) } })
assert_equal("    var x = list.Clear()", text, "a call inside an expression should not get a semicolon")

text = run_statement("    list.Count", { signatures = { void("int L.Count()", 0) } })
assert_equal("    list.Count()", text, "a non-void call should not get a semicolon")

text = run_statement("    list.Clear", { signatures = { void("void L.Clear()", 0) } })
assert_equal("    list.Clear();", text, "sanity check for the statement case")
pending = nil
setup("    list.Clear.x", #"    list.Clear")
call_parens.handle(event(METHOD))
pending.callback({ signatures = { void("void L.Clear()", 0) } })
assert_equal("    list.Clear().x", vim.api.nvim_get_current_line(), "text after the call should block the semicolon")

text, col = run_statement("    f.Say", { signatures = { { label = "void F.Say(string m)", parameters = { { label = "string m" } } } } })
assert_equal('    f.Say("");', text, "placeholder and semicolon should combine")
assert_equal(#'    f.Say("', col, "the cursor should sit between the quotes")

vim.o.virtualedit = ""

-- Built-in types behind new start an array.
local function run_type(line, kind, label)
  pending = nil
  setup(line)
  call_parens.handle(event(kind, nil, label))
  return (vim.api.nvim_get_current_line():gsub(";$", "")), vim.api.nvim_win_get_cursor(0)[2]
end

text, col = run_type("var a = new int", KEYWORD, "int")
assert_equal("var a = new int[]", text, "a built-in type after new should get brackets")
assert_equal(#"var a = new int[", col, "the cursor should sit inside the brackets")
assert_equal(nil, pending, "arrays should not query signature help")

text = run_type("int a", KEYWORD, "int")
assert_equal("int a", text, "a built-in type outside new should be left alone")

-- Generic types get angle brackets, and typing ">" steps over the closing one.
text, col = run_type("var a = new List", CLASS, "List<T>")
assert_equal("var a = new List<>", text, "a generic type should get angle brackets")
assert_equal(#"var a = new List<", col, "the cursor should sit inside the angle brackets")
assert_equal(nil, pending, "generic types should not query signature help")

local function close_key()
  return vim.fn.maparg(">", "i", false, true).callback()
end

assert_equal("<Right>()<Left>", close_key(), "closing a generic behind new should step over > and add ()")

assert_equal(nil, vim.fn.maparg(">", "i", false, true).callback, "stepping over > should disarm the mapping")

run_type("var a = new List", CLASS, "List<T>")
vim.api.nvim_buf_set_text(0, 0, #"var a = new List<", 0, #"var a = new List<", { "int" })
vim.api.nvim_win_set_cursor(0, { 1, #"var a = new List<int" })
assert_equal("<Right>()<Left>", close_key(), "typed arguments should not stop the step over")

text = run_type("List", CLASS, "List<T>")
assert_equal("List<>", text, "a generic type outside new should only get angle brackets")
assert_equal("<Right>", close_key(), "closing a generic outside new should only step over >")

run_type("var a = new Dictionary", CLASS, "Dictionary<TKey, TValue>")
vim.api.nvim_buf_set_text(0, 0, #"var a = new Dictionary<", 0, #"var a = new Dictionary<", { "string, List<int" })
vim.api.nvim_win_set_cursor(0, { 1, #"var a = new Dictionary<string, List<int" })
assert_equal(">", close_key(), "an unbalanced inner < should type a literal >")

text = run_type("var a = new Foo", CLASS, "Foo")
assert_equal("var a = new Foo()", text, "a non-generic type should still get parentheses")

print("call_parens_spec: ok")
