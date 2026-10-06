local lines = {
  "SELECT category",
  "FROM products",
  "WHERE active = 1",
  "GROUP BY category",
  "HAVING COUNT(*) > 1",
  "ORDER BY category",
  "OFFSET 10 ROWS",
  "FETCH NEXT 5 ROWS ONLY",
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.filetype = "sql"

local function press(key)
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert(mapping and mapping.callback, "missing Lua mapping for " .. key)
  mapping.callback()
end

local function move_to(line, column)
  vim.api.nvim_win_set_cursor(0, { line, column or 0 })
end

local function assert_line(expected, message)
  local actual = vim.api.nvim_win_get_cursor(0)[1]
  assert(actual == expected, string.format("%s: expected line %d, got %d", message, expected, actual))
end

move_to(3, 8)
press("]k")
assert_line(4, "WHERE should advance to GROUP BY")
press("]k")
assert_line(5, "GROUP BY should advance to HAVING")
press("]k")
assert_line(6, "HAVING should advance to ORDER BY")
press("]k")
assert_line(7, "ORDER BY should advance to OFFSET/FETCH")

move_to(7)
press("[k")
assert_line(6, "OFFSET/FETCH should move backward to ORDER BY")
press("[k")
assert_line(5, "ORDER BY should move backward to HAVING")

vim.cmd("qa!")
