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

-- Roslyn labels parameters by name only; the type is read from the signature label.
local function roslyn(label, ...)
  local parameters = {}
  for _, name in ipairs({ ... }) do table.insert(parameters, { label = name }) end
  return { label = label, parameters = parameters }
end

text = run(METHOD, "f.Say", { signatures = { roslyn("void Foo.Say(string message)", "message") } })
assert_equal('f.Say("")', text, "the type should come from the signature label")

text = run(METHOD, "l.Where", { signatures = { roslyn("(extension) IEnumerable<int> IEnumerable<int>.Where<int>(Func<int, bool> predicate)", "predicate") } })
assert_equal("l.Where(x => )", text, "extension signatures should be read without their prefix")

text = run(METHOD, "l.Where", { signatures = { roslyn("(extension) IEnumerable<int> L.Where<int>(Func<int, bool> predicate)", "predicate"), roslyn("(extension) IEnumerable<int> L.Where<int>(Func<int, int, bool> predicate)", "predicate") } })
assert_equal("l.Where()", text, "overloads with different delegate types should stay empty")

text = run(METHOD, "f.Fold", { signatures = { roslyn("int Foo.Fold(Func<int, int, int> folder)", "folder") } })
assert_equal("f.Fold((a, b) => )", text, "Func should count its inputs from the signature label")

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

-- Collection initializers on request.
vim.o.virtualedit = "onemore"
local function initializer(line, column)
  setup(line, column)
  local changed = call_parens.to_initializer()
  return changed, vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2]
end

local changed
changed, text, col = initializer("var l = new List<int>()", #"var l = new List<int>()")
assert_equal(true, changed, "a cursor after () should convert")
assert_equal("var l = new List<int> {  }", text, "() should become an initializer")
assert_equal(#"var l = new List<int> { ", col, "the cursor should sit between the braces")

changed, text, col = initializer("var l = new List<int>()", #"var l = new List<int>(")
assert_equal("var l = new List<int> {  }", text, "a cursor inside () should convert")
assert_equal(#"var l = new List<int> { ", col, "the cursor should sit between the braces")

changed, text = initializer("var d = new Dictionary<string, List<int>>();", #"var d = new Dictionary<string, List<int>>()")
assert_equal("var d = new Dictionary<string, List<int>> {  };", text, "nested generics and a trailing ; should be kept")

changed, text, col = initializer("var a = new int[3]", #"var a = new int[3]")
assert_equal("var a = new int[3] {  }", text, "an array creation should get an initializer")
assert_equal(#"var a = new int[3] { ", col, "the cursor should sit between the braces")

changed, text = initializer("var a = new int[]", #"var a = new int[]")
assert_equal("var a = new int[] {  }", text, "an unsized array should get an initializer")

changed, text = initializer("list.Clear()", #"list.Clear()")
assert_equal(false, changed, "an ordinary call must not be converted")
assert_equal("list.Clear()", text, "an ordinary call should stay unchanged")

changed = initializer("var l = new List<int> {  }", #"var l = new List<int>")
assert_equal(false, changed, "an existing initializer should not be duplicated")

changed, text = initializer("var l = new Foo(1)", #"var l = new Foo(")
assert_equal(false, changed, "a call with arguments should not be converted")
vim.o.virtualedit = ""

-- Finishing a statement: step over closers, add only a semicolon the parser reports missing.
vim.o.virtualedit = "onemore"
local function finish(statement, column)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "class A { void M() {", statement, "} }" })
  vim.bo.filetype = "cs"
  vim.api.nvim_win_set_cursor(0, { 2, column })
  local result = call_parens.finish_statement()
  return result, vim.api.nvim_buf_get_lines(0, 1, 2, false)[1], vim.api.nvim_win_get_cursor(0)[2]
end

changed, text, col = finish("    var x = list.Count()", #"    var x = list.Count(")
assert_equal(true, changed, "a missing ; should be added")
assert_equal("    var x = list.Count();", text, "the ; should follow the call")
assert_equal(#text, col, "the cursor should end after the ;")

changed, text, col = finish("    list.Add(items.First())", #"    list.Add(items.First(")
assert_equal("    list.Add(items.First());", text, "nested closers should all be stepped over")
assert_equal(#text, col, "the cursor should end after the ;")

changed, text = finish("    return a.B(c(d))  // note", #"    return a.B(c(d")
assert_equal("    return a.B(c(d));  // note", text, "the ; should go before a trailing comment")

changed, text = finish("    var a = new int[3]", #"    var a = new int[3")
assert_equal("    var a = new int[3];", text, "brackets should be stepped over as well")

changed, text = finish("    list.Clear();", #"    list.Clear(")
assert_equal("    list.Clear();", text, "an existing ; should not be doubled")
assert_equal(true, changed, "stepping over the closers still counts as a change")

changed, text, col = finish("    list.Clear();", #"    list.Clear();")
assert_equal(false, changed, "a finished statement at its end should change nothing")

changed, text = finish("    if (x)", #"    if (x")
assert_equal("    if (x)", text, "the empty statement after if () must not get a ;")

changed, text = finish("    for (int i = 0; i < 3; i++)", #"    for (int i = 0; i < 3; i++")
assert_equal("    for (int i = 0; i < 3; i++)", text, "a for header must not get a ;")

changed, text = finish("    while (running)", #"    while (running")
assert_equal("    while (running)", text, "a while header must not get a ;")

changed, text = finish("    foo.Bar(1,", #"    foo.Bar(1,")
assert_equal("    foo.Bar(1,", text, "an unfinished argument list must be left alone")

changed, text = finish("    var f = x =>", #"    var f = x =>")
assert_equal("    var f = x =>", text, "an unfinished lambda must be left alone")

local function finish_rows(lines, row, column)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "cs"
  vim.api.nvim_win_set_cursor(0, { row, column })
  local result = call_parens.finish_statement()
  return result, vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function inside_method(statement) return { "class A { void M() {", statement, "} }" } end

for _, case in ipairs({
  { "    throw new Exception()", "    throw new Exception();" },
  { "    yield return f()", "    yield return f();" },
  { "    break", "    break;" },
  { "    continue", "    continue;" },
  { "    do { } while (x)", "    do { } while (x);" },
}) do
  _, text = finish(case[1], #case[1])
  assert_equal(case[2], text, case[1] .. " should get its ;")
end

_, text = finish("    do { } while (x)", #"    do { } while (x")
assert_equal("    do { } while (x);", text, "closers inside a do-while condition should be stepped over")

local rows
changed, rows = finish_rows({ "class A {", "  int x = 1", "}" }, 2, #"  int x = 1")
assert_equal("  int x = 1;", rows[2], "a field declaration should get its ;")

changed, rows = finish_rows({ "class A {", "  public int X { get; set; } = 1", "}" }, 2, #"  public int X { get; set; } = 1")
assert_equal("  public int X { get; set; } = 1;", rows[2], "a property initializer should get its ;")

changed, rows = finish_rows({ "class A { int P => f()", "}" }, 1, #"class A { int P => f()")
assert_equal("class A { int P => f();", rows[1], "an expression body should get its ;")

changed, rows = finish_rows({ "class A {", "  public int X { get; set; }", "}" }, 2, #"  public int X { get; set; }")
assert_equal("  public int X { get; set; }", rows[2], "a property without initializer must not get a ;")

changed, rows = finish_rows({ "abstract class A {", "  void M()", "}" }, 2, #"  void M()")
assert_equal("  void M()", rows[2], "a method header must not become an abstract declaration")

changed, rows = finish_rows({ "class A { void M() {", "    var x = list", "        .Where(a => a)", "        .ToList()", "} }" }, 4, #"        .ToList()")
assert_equal("        .ToList();", rows[4], "a chain should get its ; on the last row")
assert_equal("    var x = list", rows[2], "earlier rows of the chain should stay untouched")

changed, rows = finish_rows({ "class A { void M() {", "    var x = a.B(", "        c(d))", "} }" }, 3, #"        c(d))")
assert_equal("        c(d));", rows[3], "a call spanning rows should get its ; on the last row")

-- Top-level statements, usings and lambda bodies are deliberately left alone.
changed, rows = finish_rows({ "var x = list.Count()", "Console.WriteLine(x);" }, 1, #"var x = list.Count()")
assert_equal("var x = list.Count()", rows[1], "a top-level statement should be left alone")

changed, rows = finish_rows({ "using System", "class A { }" }, 1, #"using System")
assert_equal("using System", rows[1], "a using directive should be left alone")

changed, rows = finish_rows(inside_method("    Action a = () => { f() };"), 2, #"    Action a = () => { f(")
assert_equal("    Action a = () => { f() };", rows[2], "a statement inside a lambda body should be left alone")

-- No scratch buffer may outlive a check, whether it accepted the ; or not.
local buffers = #vim.api.nvim_list_bufs()
finish("    var x = list.Count()", #"    var x = list.Count(")
finish("    if (f)", #"    if (f")
assert_equal(buffers, #vim.api.nvim_list_bufs(), "finish_statement should not leak scratch buffers")

-- Target-typed new keeps its "()".
changed, text, col = initializer("List<int> l = new()", #"List<int> l = new()")
assert_equal(true, changed, "target-typed new should convert")
assert_equal("List<int> l = new() {  }", text, "target-typed new should keep its ()")
assert_equal(#"List<int> l = new() { ", col, "the cursor should sit between the braces")

changed, text = initializer("var l = new()  ", #"var l = new(")
assert_equal("var l = new() {  }", text:gsub("%s+$", ""), "a cursor inside new() should convert as well")

-- The generic ">" mapping goes away on leaving insert mode and on changing rows.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "var a = new List", "next row" })
vim.api.nvim_win_set_cursor(0, { 1, #"var a = new List" })
call_parens.handle(event(CLASS, nil, "List<T>"))
assert_equal("function", type(vim.fn.maparg(">", "i", false, true).callback), "the mapping should be armed")
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 })
assert_equal(nil, vim.fn.maparg(">", "i", false, true).callback, "InsertLeave should disarm the mapping")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "var a = new List", "next row" })
vim.api.nvim_win_set_cursor(0, { 1, #"var a = new List" })
call_parens.handle(event(CLASS, nil, "List<T>"))
vim.api.nvim_exec_autocmds("CursorMovedI", { buffer = 0 })
assert_equal("function", type(vim.fn.maparg(">", "i", false, true).callback), "moving within the row should keep it armed")
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.api.nvim_exec_autocmds("CursorMovedI", { buffer = 0 })
assert_equal(nil, vim.fn.maparg(">", "i", false, true).callback, "changing rows should disarm the mapping")

-- The C# editing keys exist in C# buffers only.
vim.cmd("enew")
vim.bo.filetype = "cs"
for _, key in ipairs({ "<M-i>", "<M-CR>" }) do
  assert_equal(1, vim.fn.maparg(key, "i", false, true).buffer, key .. " should be mapped in a C# buffer")
end
vim.cmd("enew")
vim.bo.filetype = "lua"
for _, key in ipairs({ "<M-i>", "<M-CR>" }) do
  assert_equal(true, vim.tbl_isempty(vim.fn.maparg(key, "i", false, true)), key .. " should not be mapped outside C#")
end

vim.o.virtualedit = ""

print("call_parens_spec: ok")
