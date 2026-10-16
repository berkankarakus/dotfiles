-- <leader>cf formats JSON with jq. jq has no range mode, so conform formats the whole document and applies
-- only the changes overlapping the selection; invalid JSON must leave the buffer untouched.
local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

require("lazy").load({ plugins = { "conform.nvim" } })
local conform = require("conform")
assert(vim.deep_equal({ "jq" }, conform.formatters_by_ft.json), "json should be formatted with jq")
assert(conform.formatters_by_ft.jsonc == nil, "jsonc must not use jq: it cannot parse comments")

if vim.fn.executable("jq") == 0 then
  print("json_format_spec: skipped (jq is not installed)")
  vim.cmd("qa!")
end

local function format(lines, range)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "json"
  vim.bo.shiftwidth = 4
  local options = { bufnr = 0, async = false, timeout_ms = 3000, lsp_format = "never", quiet = true }
  options.range = range
  conform.format(options)
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local compact = { "{", '"a":1,', '"b":[1,2]', "}" }

local whole = format(compact)
assert_equal("{", whole[1], "the opening brace stays")
assert_equal('    "a": 1,', whole[2], "the buffer should be indented with shiftwidth")
assert_equal('        1,', whole[4], "arrays should be expanded one element per line")
assert_equal("}", whole[#whole], "the closing brace stays")

local ranged = format(compact, { start = { 2, 0 }, ["end"] = { 2, 6 } })
assert_equal("{", ranged[1], "a line outside the selection must not change")
assert_equal('    "a": 1,', ranged[2], "the selected line should be formatted")
assert_equal("}", ranged[#ranged], "the last line outside the selection must not change")

local broken = { '{"a":1,,}' }
assert(vim.deep_equal(broken, format(broken)), "invalid JSON should leave the buffer untouched")

print("json_format_spec: ok")
vim.cmd("qa!")
