local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

vim.api.nvim_exec_autocmds("InsertEnter", {})
vim.wait(1000, function() return require("lazy.core.config").plugins["nvim-cmp"]._.loaded end)
local ls = require("luasnip")

local function snippet(trigger)
  for _, candidate in ipairs(ls.get_snippets("cs")) do
    if candidate.trigger == trigger then return candidate end
  end
  error("missing C# snippet " .. trigger)
end

-- Expands a snippet after `prefix` and returns the buffer lines.
local function expand(trigger, prefix)
  vim.cmd("enew!")
  vim.bo.filetype = "cs"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { 1, #prefix })
  vim.cmd("startinsert!")
  ls.snip_expand(snippet(trigger))
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- The unfilled snippet shows its placeholders.
local lines = expand("swe", "var y = ")
assert_equal("var y = value switch", lines[1], "the switch expression should start with a value")
assert_equal("{", lines[2], "the opening brace should sit on its own row")
assert_equal("    pattern => result,", lines[3], "the first arm should be a placeholder")
assert_equal("    _ => default,", lines[4], "the discard arm should close the switch")
assert_equal("}", lines[5], "the closing brace should sit on its own row")

-- Tab grows the arms. `type_into` replaces the current placeholder like typing over it.
local function current_node() return ls.session.current_nodes[vim.api.nvim_get_current_buf()] end
local function type_into(text)
  local from, to = current_node():get_buf_position()
  vim.api.nvim_buf_set_text(0, from[1], from[2], to[1], to[2], { text })
end
local function current_text() return table.concat(current_node():get_text(), "\n") end
local function buffer_lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local swe = require("neo.snippets")

expand("swe", "var y = ")
ls.jump(1) -- onto the first pattern
type_into("1")
ls.jump(1)
type_into('"one"')
assert_equal(true, swe.switch_tab(), "Tab on a typed result should be handled")
assert_equal('    1 => "one",', buffer_lines()[3], "the typed arm should stay")
assert_equal("    pattern => result,", buffer_lines()[4], "a new arm should appear below it")
assert_equal("pattern", current_text(), "the cursor should land in the new arm's pattern")

type_into("2")
ls.jump(1)
type_into('"two"')
assert_equal(true, swe.switch_tab(), "Tab on a second typed result should be handled")
assert_equal("    pattern => result,", buffer_lines()[5], "a third arm should appear")

-- An untouched pattern takes its arm away and moves on to the default.
assert_equal(true, swe.switch_tab(), "Tab on an untouched pattern should be handled")
local lines = buffer_lines()
assert_equal(6, #lines, "the empty arm should be gone again")
assert_equal('    2 => "two",', lines[4], "the earlier arms should stay")
assert_equal("    _ => default,", lines[5], "the default arm should follow them")
assert_equal("default", current_text(), "the cursor should land on the default")

-- With the placeholders replaced and a ";" added, the result must parse as a switch expression.
local filled = table.concat(lines, "\n"):gsub("value", "n"):gsub("default", '"many"')
local source = "class A { string M(int n) {\n" .. filled .. ";\nreturn y; } }"
local root = vim.treesitter.get_string_parser(source, "c_sharp"):parse()[1]:root()
assert_equal(false, root:has_error(), "the grown switch expression should parse cleanly: " .. source)
local found = false
local function walk(node)
  if node:type() == "switch_expression" then found = true end
  for child in node:iter_children() do walk(child) end
end
walk(root)
assert_equal(true, found, "the parse tree should contain a switch expression")

-- An untouched result moves straight on to the default without adding an arm.
expand("swe", "return ")
ls.jump(1)
type_into("1")
ls.jump(1)
assert_equal(true, swe.switch_tab(), "Tab on an untouched result should be handled")
assert_equal(5, #buffer_lines(), "no arm should be added")
assert_equal("default", current_text(), "the cursor should land on the default")

-- Other snippets and the first arm's pattern are left to the normal Tab.
expand("if", "")
assert_equal(false, swe.switch_tab(), "Tab in another snippet should not be handled")
expand("swe", "var y = ")
ls.jump(1)
assert_equal(false, swe.switch_tab(), "Tab on the first pattern should be left to the normal jump")

-- Collection declarations: the type is written once, the right side is an empty collection expression.
for _, case in ipairs({
  { "lst", "List<int> items = [];", { "int", "items" }, "[" },
  { "hset", "HashSet<int> items = [];", { "int", "items" }, "[" },
  { "arr", "int[] values = [];", { "int", "values" }, "[" },
  { "dict", "Dictionary<string, int> map = new() { [key] = value };", { "string", "int", "map", "key", "value" } },
  { "queue", "Queue<int> queue = new([]);", { "int", "queue" }, "[" },
  { "stack", "Stack<int> stack = new([]);", { "int", "stack" }, "[" },
}) do
  local trigger, expected, stops, inside = case[1], case[2], case[3], case[4]
  local lines = expand(trigger, "")
  assert_equal(1, #lines, trigger .. " should expand to one line")
  assert_equal(expected, lines[1], trigger .. " should expand to " .. expected)
  assert_equal(stops[1], current_text(), trigger .. ": the first stop should be the type")
  for index = 2, #stops do
    ls.jump(1)
    assert_equal(stops[index], current_text(), trigger .. ": stop " .. index)
  end
  if inside then
    -- The final stop sits between the brackets, before the ";".
    local from, to = current_node().parent.insert_nodes[0]:get_buf_position()
    local bracket = lines[1]:match(".*()%[")
    assert_equal(bracket, from[2], trigger .. ": the final stop should sit right after [")
    assert_equal(bracket, to[2], trigger .. ": and be empty")
  end

  -- With the placeholders filled in, the line must parse as a declaration.
  local source = "class A { void M() {\n" .. expected .. "\n} }"
  local root = vim.treesitter.get_string_parser(source, "c_sharp"):parse()[1]:root()
  assert_equal(false, root:has_error(), trigger .. ": the expansion should parse cleanly: " .. source)
end

print("snippets_spec: ok")
