local csharp = require("neo.csharp")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local root = vim.uv.fs_realpath(vim.fn.tempname() .. "-skeleton") or vim.fn.tempname() .. "-skeleton"
vim.fn.mkdir(root .. "/Models", "p")
vim.fn.writefile({ "<Project><PropertyGroup><RootNamespace>My.App</RootNamespace></PropertyGroup></Project>" }, root .. "/App.csproj")

local function skeleton_of(path)
  vim.cmd("silent edit " .. vim.fn.fnameescape(path))
  vim.cmd("stopinsert")
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- A new file in a subfolder gets the namespace from the project root plus the folder.
local lines = skeleton_of(root .. "/Models/Person.cs")
assert_equal("namespace My.App.Models;", lines[1], "namespace should combine RootNamespace and folder")
assert_equal("public class Person()", lines[6], "a class skeleton should be generated")
assert_equal("/// <summary>", lines[3], "the skeleton should start with a summary")

-- Interfaces follow the I-prefix convention.
lines = skeleton_of(root .. "/IService.cs")
assert_equal("public interface IService", lines[6], "I-prefixed names should become interfaces")

-- An existing empty file (touch NewClass.cs) is filled via BufReadPost.
vim.fn.writefile({}, root .. "/Touched.cs")
lines = skeleton_of(root .. "/Touched.cs")
assert_equal("namespace My.App;", lines[1], "an empty existing file should get a skeleton")

-- A file that already has content is left alone.
vim.fn.writefile({ "// keep me" }, root .. "/Existing.cs")
lines = skeleton_of(root .. "/Existing.cs")
assert_equal("// keep me", lines[1], "existing content must not be replaced")
assert_equal(1, #lines, "existing content must not get a skeleton appended")

-- Outside any .csproj nothing is generated.
local orphan = vim.fn.tempname() .. "-orphan"
vim.fn.mkdir(orphan, "p")
lines = skeleton_of(orphan .. "/Loose.cs")
assert_equal("", lines[1], "files without a project stay empty")

-- Running setup again must not stack duplicate autocmds.
local function count()
  return #vim.api.nvim_get_autocmds({ group = "CSharpFileSkeleton" })
end
local before = count()
csharp.setup()
csharp.setup()
assert_equal(before, count(), "setup should be idempotent")
assert(before > 0, "the skeleton autocmds should be registered by setup")

vim.fn.delete(root, "rf")
vim.fn.delete(orphan, "rf")
print("csharp_new_file_spec: ok")
vim.cmd("qa!")
