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

-- With the placeholders replaced and a ";" added, the result must parse as a switch expression.
lines = expand("swe", "var y = ")
local filled = table.concat(lines, "\n")
  :gsub("value", "n"):gsub("pattern", "1"):gsub("result", '"one"'):gsub("default", '"many"')
local source = "class A { string M(int n) {\n" .. filled .. ";\nreturn y; } }"
local parser = vim.treesitter.get_string_parser(source, "c_sharp")
local root = parser:parse()[1]:root()
assert_equal(false, root:has_error(), "a filled-in switch expression should parse cleanly: " .. source)
local found = false
local function walk(node)
  if node:type() == "switch_expression" then found = true end
  for child in node:iter_children() do walk(child) end
end
walk(root)
assert_equal(true, found, "the parse tree should contain a switch expression")

print("snippets_spec: ok")
