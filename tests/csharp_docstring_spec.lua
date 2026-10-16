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

-- Parameter parsing must survive generics, tuples, attributes and string defaults.
local function docstring_for(declaration_lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, declaration_lines)
  vim.bo.filetype = "cs"
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  csharp.insert_docstring()
  vim.wait(20)
  local params, returns = {}, false
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    local name = line:match('<param name="([^"]+)">')
    if name then params[#params + 1] = name end
    if line:find("<returns>", 1, true) then returns = true end
  end
  return table.concat(params, ","), returns
end

local params, returns = docstring_for({ "    public void Run(Dictionary<string, int> map, int count = 3)" })
assert_equal("map,count", params, "generic argument lists should not split into parameters")
assert_equal(false, returns, "void methods have no returns tag")

params, returns = docstring_for({ '    public (int, string) Pair((int a, int b) tuple, string s = "a,b")' })
assert_equal("tuple,s", params, "tuple types and string defaults should not split into parameters")
assert_equal(true, returns, "a tuple return type should get a returns tag")

params = docstring_for({ "    public Task<IReadOnlyList<int>> LoadAsync<T>(Func<T, bool> filter, params int[] ids)" })
assert_equal("filter,ids", params, "generic methods with nested generics should list their parameters")

params = docstring_for({ "    public void Save([NotNull] string path, out int written, string sep = \",\")" })
assert_equal("path,written,sep", params, "attributes, out parameters and string defaults should be handled")

params = docstring_for({ "    public void Configure(", "        string name,", "        Dictionary<string, int> map)" })
assert_equal("name,map", params, "multi-line parameter lists should be collected")

params = docstring_for({ "    public Calculator(int seed) : base(seed, 1)" })
assert_equal("seed", params, "base initializer arguments should not become parameters")

params, returns = docstring_for({ "    public int Total => Items.Count(x => x.Ok);" })
assert_equal("", params, "an expression-bodied property has no parameters")
assert_equal(false, returns, "an expression-bodied property gets no returns tag")

_, returns = docstring_for({ "    public Calculator(int seed) : base(seed, 1)" })
assert_equal(false, returns, "constructors have no returns tag")

params, returns = docstring_for({ "class Calculator", "{", "    public Calculator Create(int seed)" })
assert_equal("", params, "a class line must not borrow the next method's parameters")
assert_equal(false, returns, "a class line must not get a returns tag")

params, returns = docstring_for({ "    public int Count { get; }", "    public void Run(int a)" })
assert_equal("", params, "a property must not borrow the next method's parameters")
assert_equal(false, returns, "a property must not get a returns tag")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "class Calculator", "{", "    public Calculator Create(int seed)", "}" })
vim.api.nvim_win_set_cursor(0, { 3, 4 })
csharp.insert_docstring()
vim.wait(20)
local has_returns = false
for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
  if line:find("<returns>", 1, true) then has_returns = true end
end
assert_equal(true, has_returns, "a method returning its own class should get a returns tag")

assert_equal("a<b,c>", table.concat(csharp._split_parameters("a<b,c>"), "|"), "commas inside <> stay together")
assert_equal("x", csharp._parameter_name('List<int> x = new() { 1, 2 }'), "defaults with braces should be skipped")

vim.cmd("qa!")
