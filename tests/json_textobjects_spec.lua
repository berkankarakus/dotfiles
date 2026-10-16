-- JSON reuses the existing text object keys: ab/ib for objects and arrays, aa/ia for pairs and
-- array elements (aa takes the following comma, or the preceding one for the last element).
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

print("json_textobjects_spec: ok")
vim.cmd("qa!")
