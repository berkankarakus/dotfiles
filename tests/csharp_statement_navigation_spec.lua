local lines = {
  "class C",
  "{",
  "  void M()",
  "  {",
  "    Before();",
  "    if (ready)",
  "    {",
  "      Inside();",
  "    }",
  "    After();",
  "  }",
  "}",
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.filetype = "cs"

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

move_to(5, 4)
press("]k")
assert_line(6, "C# statement movement should reach the if statement")
press("]k")
assert_line(8, "C# statement movement should enter a block without stopping on the block")
press("]k")
assert_line(10, "C# statement movement should continue after a nested block")

press("[k")
assert_line(8, "C# statement movement should move backward through nested statements")
press("[k")
assert_line(6, "C# statement movement should skip the block when moving backward")

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "class Navigation",
  "{",
  "  private int count;",
  "  void Run() {}",
  "}",
})
move_to(1, 0)
press("]k")
assert_line(3, "C# movement should include field declarations")
press("]k")
assert_line(4, "C# movement should include method declarations")
press("[k")
assert_line(3, "C# backward movement should include field declarations")
press("[k")
assert_line(1, "C# movement should include class declarations")

vim.cmd("qa!")
