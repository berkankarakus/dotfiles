local csharp = require("neo.csharp")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %q, got %q)", message, expected, actual))
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "class Calculator",
  "{",
  "    public int Add(int left, int right)",
  "    {",
  "        return left + right;",
  "    }",
  "}",
})
vim.bo.filetype = "cs"
vim.api.nvim_win_set_cursor(0, { 3, 4 })
csharp.insert_docstring()
vim.wait(20)

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert_equal("    /// <summary>", lines[3], "docstring should be inserted above the method")
assert_equal('    /// <param name="left"></param>', lines[6], "docstring should include first parameter")
assert_equal('    /// <param name="right"></param>', lines[7], "docstring should include second parameter")
assert_equal("    /// <returns></returns>", lines[8], "non-void method should include returns documentation")

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "/// <summary>",
  "/// description",
  "/// ",
  "/// </summary>",
  '/// <param name="value"></param>',
  "int Run() => 0;",
})
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert_equal(true, csharp.jump_docstring_field(), "Tab target should be available in a docstring")
assert_equal(3, vim.api.nvim_win_get_cursor(0)[1], "Tab should jump to the summary body")
assert_equal(true, csharp.jump_docstring_field(), "Tab should advance to the parameter field")
assert_equal(5, vim.api.nvim_win_get_cursor(0)[1], "Tab should jump to the parameter value")
assert_equal(false, csharp.jump_docstring_field(), "Tab should leave the docstring after its final field")

vim.bo.filetype = "lua"
assert_equal(false, csharp.jump_docstring_field(), "docstring navigation should be inactive outside C#")

vim.cmd("qa!")
