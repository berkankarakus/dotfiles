-- JSON reuses the existing keys. Text objects: ab/ib for objects and arrays, aa/ia for pairs and
-- array elements (aa takes the following comma, or the preceding one for the last element).
-- Motions: ]k/[k hop between pairs and elements, ]r jumps to the next object or array and [r
-- climbs to the enclosing one (previous one, wrapping, when already at the root).
local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local json = '{"name": "app", "tags": ["a", "b", "c"], "nested": {"x": 1, "y": 2}, "only": [7]}'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { json })
vim.bo.filetype = "json"
assert(vim.treesitter.get_parser(0, nil, { error = false }), "the json parser must be installed (see lua/neo/plugins/treesitter.lua)")

local function column_of(text) return (json:find(text, 1, true)) - 1 end

-- Selects with real keys and returns what was yanked.
local function select(column, keys)
  vim.api.nvim_win_set_cursor(0, { 1, column })
  vim.fn.setreg('"', "")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. keys .. "y"), "x", false)
  return vim.fn.getreg('"')
end

local x = column_of('"x"')
assert_equal('{"x": 1, "y": 2}', select(x, "vab"), "ab should select the whole object")
assert_equal('"x": 1, "y": 2', select(x, "vib"), "ib should select the object contents without braces")

local b = column_of('"b"')
assert_equal('["a", "b", "c"]', select(b, "vab"), "ab should select the whole array")
assert_equal('"a", "b", "c"', select(b, "vib"), "ib should select the array contents without brackets")

assert_equal('"x": 1,', select(x, "vaa"), "aa should take a pair with its following comma")
assert_equal('"x": 1', select(x, "via"), "ia should select just the pair")
assert_equal('"b",', select(b, "vaa"), "aa should take an array element with its following comma")
assert_equal('"b"', select(b, "via"), "ia should select just the element")
assert_equal('"name": "app",', select(column_of('"name"') + 1, "vaa"), "aa should work from the key")

local c = column_of('"c"')
assert_equal(', "c"', select(c, "vaa"), "aa on the last array element should take the preceding comma")
assert_equal('"c"', select(c, "via"), "ia on the last element should not include a comma")
local y = column_of('"y"')
assert_equal(', "y": 2', select(y, "vaa"), "aa on the last pair should take the preceding comma")

local seven = column_of("7")
assert_equal("7", select(seven, "vaa"), "aa on a lone element has no comma to take")
assert_equal("[7]", select(seven, "vab"), "ab should still select the surrounding array")

-- Motions, on a formatted document so lines and columns are easy to follow.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "{",                  -- 1
  '  "name": "app",',   -- 2
  '  "tags": [',        -- 3
  '    "a",',           -- 4
  '    "b"',            -- 5
  "  ],",               -- 6
  '  "nested": {',      -- 7
  '    "x": 1',         -- 8
  "  }",                -- 9
  "}",                  -- 10
})

local function press(key)
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert(mapping and mapping.callback, "missing mapping " .. key)
  mapping.callback()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] .. ":" .. cursor[2]
end

local function walk(start_line, start_col, key, expected)
  vim.api.nvim_win_set_cursor(0, { start_line, start_col })
  for step, position in ipairs(expected) do
    assert_equal(position, press(key), string.format("%s step %d", key, step))
  end
end

-- name -> tags -> "a" -> "b" -> nested -> x, then wrap to name.
walk(2, 2, "]k", { "3:2", "4:4", "5:4", "7:2", "8:4", "2:2" })
-- And back, wrapping from name to x.
walk(8, 4, "[k", { "7:2", "5:4", "4:4", "3:2", "2:2", "8:4" })
-- Objects and arrays by start: tags array, nested object, wrap to the root object.
walk(2, 2, "]r", { "3:10", "7:12", "1:0" })
-- [r climbs outward: x -> nested object -> root. The root has no parent, so [r then goes to the
-- previous block and wraps to the last one (the nested object), mirroring ]r wrapping to the root.
walk(8, 4, "[r", { "7:12", "1:0", "7:12", "1:0" })
-- From the very start of the document [r reaches the end, the way ]r reaches the start from the end.
walk(1, 0, "[r", { "7:12" })
walk(7, 12, "]r", { "1:0" })
-- From inside the tags array the parent is the array itself.
walk(4, 4, "[r", { "3:10" })

print("json_textobjects_spec: ok")
vim.cmd("qa!")
