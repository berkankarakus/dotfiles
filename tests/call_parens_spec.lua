local call_parens = require("neo.call_parens")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local METHOD, CLASS = 2, 7

local function event(kind, commit_character)
  return {
    commit_character = commit_character,
    entry = { get_completion_item = function() return { kind = kind } end },
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

print("call_parens_spec: ok")
