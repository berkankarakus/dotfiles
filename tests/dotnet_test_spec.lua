local runner = require("neo.dotnet_test")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local function open(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "cs"
  return vim.api.nvim_get_current_buf()
end

local function at(buf, line, column)
  local target = runner.test_name(buf, line - 1, column or 0)
  return target and (target.kind .. ":" .. target.name) or nil
end

-- --------------------------------------------------- file-scoped namespace
local buf = open({
  "namespace My.App.Tests;",       -- 1
  "",                              -- 2
  "public class CalcTests",        -- 3
  "{",                             -- 4
  "    [Fact]",                    -- 5
  "    public void Adds()",        -- 6
  "    {",                         -- 7
  "        var x = 1 + 1;",        -- 8
  "    }",                         -- 9
  "",                              -- 10
  "    private int Helper() => 1;",-- 11
  "}",                             -- 12
})
assert_equal("method:My.App.Tests.CalcTests.Adds", at(buf, 8, 10), "inside the method body")
assert_equal("method:My.App.Tests.CalcTests.Adds", at(buf, 5, 6), "on the attribute above the method")
assert_equal("method:My.App.Tests.CalcTests.Adds", at(buf, 6, 20), "on the method signature")
assert_equal("method:My.App.Tests.CalcTests.Helper", at(buf, 11, 20), "an expression-bodied method")
assert_equal("class:My.App.Tests.CalcTests", at(buf, 4, 0), "between members the class is run")
assert_equal("class:My.App.Tests.CalcTests", at(buf, 3, 15), "on the class line")
assert_equal(nil, at(buf, 1, 5), "on the namespace line there is nothing to run")

-- ------------------------------------------------ block namespace, nesting
buf = open({
  "namespace Outer.Inner",         -- 1
  "{",                             -- 2
  "    public class Top",          -- 3
  "    {",                         -- 4
  "        public class Nested",   -- 5
  "        {",                     -- 6
  "            [Fact]",            -- 7
  "            public void Deep() { }", -- 8
  "        }",                     -- 9
  "        public void Shallow() { }", -- 10
  "    }",                         -- 11
  "}",                             -- 12
})
assert_equal("method:Outer.Inner.Top+Nested.Deep", at(buf, 8, 30), "nested classes are joined with +")
assert_equal("method:Outer.Inner.Top.Shallow", at(buf, 10, 30), "a method of the outer class")
assert_equal("class:Outer.Inner.Top+Nested", at(buf, 6, 0), "the innermost class when between members")

-- ---------------------------------------------- no namespace, other shapes
buf = open({ "public class Plain", "{", "    public void M() { }", "}" })
assert_equal("method:Plain.M", at(buf, 3, 22), "a class without a namespace")

buf = open({ "public record Point(int X, int Y)", "{", "    public int Sum() => X + Y;", "}" })
assert_equal("method:Point.Sum", at(buf, 3, 25), "records are types too")

buf = open({ "var x = 1;", "System.Console.WriteLine(x);" })
assert_equal(nil, at(buf, 2, 3), "top-level statements have no test to run")

-- ------------------------------------------------------------------ command
-- Verified against a real xUnit project: these filters run exactly Adds (not Adds2 or another class's
-- Adds), both rows of a Theory, one nested test, and a class with its nested classes but not CalcTests2.
local method = { kind = "method", name = "My.App.Tests.CalcTests.Adds" }
assert_equal("FullyQualifiedName=My.App.Tests.CalcTests.Adds|FullyQualifiedName~My.App.Tests.CalcTests.Adds\\(",
  runner.filter(method), "a method is matched exactly, or followed by an opening parenthesis")
assert_equal("FullyQualifiedName~My.App.Tests.CalcTests.|FullyQualifiedName~My.App.Tests.CalcTests+",
  runner.filter({ kind = "class", name = "My.App.Tests.CalcTests" }), "a class matches its methods and nested classes only")

local command = runner.command("/tmp/My Tests/App.Tests.csproj", method)
assert_equal("dotnet test '/tmp/My Tests/App.Tests.csproj' --filter "
  .. "'FullyQualifiedName=My.App.Tests.CalcTests.Adds|FullyQualifiedName~My.App.Tests.CalcTests.Adds\\('", command,
  "paths and the filter are shell-quoted")

-- --------------------------------------------------------- run(): the flow
local root = vim.uv.fs_realpath(vim.fn.tempname() .. "-tests") or vim.fn.tempname() .. "-tests"
vim.fn.mkdir(root .. "/App.Tests/Sub", "p")
root = vim.uv.fs_realpath(root)
vim.fn.writefile({ "<Project/>" }, root .. "/App.Tests/App.Tests.csproj")
local source = root .. "/App.Tests/Sub/CalcTests.cs"
vim.fn.writefile({
  "namespace App.Tests;",
  "public class CalcTests",
  "{",
  "    [Fact]",
  "    public void Adds()",
  "    {",
  "        var x = 1;",
  "    }",
  "}",
}, source)

local notes = {}
local original_notify = vim.notify
vim.notify = function(message, level) notes[#notes + 1] = { message = message, level = level } end
local sent
local default_runner = runner.runner
runner.runner = function(text) sent = text end

vim.cmd("silent edit " .. vim.fn.fnameescape(source))
vim.api.nvim_win_set_cursor(0, { 7, 10 })
runner.run()
assert_equal(string.format("dotnet test '%s/App.Tests/App.Tests.csproj' --filter "
  .. "'FullyQualifiedName=App.Tests.CalcTests.Adds|FullyQualifiedName~App.Tests.CalcTests.Adds\\('", root), sent,
  "the nearest project and the method name are used")
assert(notes[#notes].message:find("Running method App.Tests.CalcTests.Adds", 1, true), "the user sees what runs: " .. notes[#notes].message)

sent = nil
vim.api.nvim_win_set_cursor(0, { 1, 3 })
runner.run()
assert_equal(nil, sent, "nothing runs on the namespace line")
assert_equal(vim.log.levels.WARN, notes[#notes].level, "the user is told why")

vim.bo.filetype = "lua"
runner.run()
assert_equal(nil, sent, "not in C# files")
assert(notes[#notes].message:find("only available in C# files", 1, true), "the user is told why: " .. notes[#notes].message)

local orphan = vim.fn.tempname() .. "-orphan"
vim.fn.mkdir(orphan, "p")
vim.fn.writefile({ "class A { void M() { } }" }, orphan .. "/A.cs")
vim.cmd("silent edit " .. vim.fn.fnameescape(orphan .. "/A.cs"))
vim.bo.filetype = "cs"
vim.api.nvim_win_set_cursor(0, { 1, 18 })
runner.run()
assert_equal(nil, sent, "no project, nothing runs")
assert(notes[#notes].message:find("No .csproj", 1, true), "the user is told why: " .. notes[#notes].message)
vim.notify = original_notify

-- ------------------------------------------- the default runner and mapping
-- The default runner hands the command to the built-in terminal (neo.terminal.run).
local terminal_sent
local original_terminal_run = require("neo.terminal").run
assert(original_terminal_run, "neo.terminal should expose run after setup")
require("neo.terminal").run = function(text) terminal_sent = text end
default_runner("dotnet test --filter x")
require("neo.terminal").run = original_terminal_run
assert_equal("dotnet test --filter x", terminal_sent, "the default runner should send to the terminal")

local mapping = vim.fn.maparg(" rt", "n", false, true)
assert(mapping.lhs and mapping.lhs ~= "", "<leader>rt should be mapped")

vim.fn.delete(root, "rf")
vim.fn.delete(orphan, "rf")
print("dotnet_test_spec: ok")
vim.cmd("qa!")
