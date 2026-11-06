local csharp = require("neo.csharp")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local root = vim.uv.fs_realpath(vim.fn.tempname() .. "-skeleton") or vim.fn.tempname() .. "-skeleton"
vim.fn.mkdir(root .. "/Models", "p")
vim.fn.writefile({ "<Project><PropertyGroup><RootNamespace>My.App</RootNamespace></PropertyGroup></Project>" }, root .. "/App.csproj")

local function skeleton_of(path)
  vim.cmd("silent edit " .. vim.fn.fnameescape(path))
  vim.wait(50)
  vim.cmd("stopinsert")
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- A new file in a subfolder gets the namespace from the project root plus the folder.
local lines = skeleton_of(root .. "/Models/Person.cs")
assert_equal("namespace My.App.Models;", lines[1], "namespace should combine RootNamespace and folder")
assert_equal("public class Person()", lines[6], "a class skeleton should be generated")
assert_equal("/// <summary>", lines[3], "the skeleton should start with a summary")

-- A workspace edit may create an empty buffer and populate it immediately afterwards.
-- The skeleton must not win that race and prepend a duplicate namespace/type.
local moved = root .. "/Moved.cs"
vim.cmd("enew")
vim.cmd("file " .. vim.fn.fnameescape(moved))
local original_schedule = vim.schedule
local scheduled = {}
vim.schedule = function(callback) scheduled[#scheduled + 1] = callback end
vim.api.nvim_exec_autocmds("BufNewFile", { buffer = 0, modeline = false })
vim.schedule = original_schedule
vim.api.nvim_buf_set_lines(0, 0, 0, false, { "namespace My.App;", "public class Moved {}" })
local moved_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
if moved_lines[#moved_lines] == "" then vim.api.nvim_buf_set_lines(0, #moved_lines - 1, -1, false, {}) end
for _, callback in ipairs(scheduled) do callback() end
lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert_equal("namespace My.App;", lines[1], "workspace-created files should keep the applied namespace")
assert_equal("public class Moved {}", lines[2], "workspace-created files should keep the applied type")
assert_equal(2, #lines, "workspace-created files must not receive a second skeleton")

-- Interfaces follow the I-prefix convention.
lines = skeleton_of(root .. "/IService.cs")
assert_equal("public interface IService", lines[6], "I-prefixed names should become interfaces")

-- An existing empty file (touch NewClass.cs) is filled via BufReadPost.
vim.fn.writefile({}, root .. "/Touched.cs")
lines = skeleton_of(root .. "/Touched.cs")
assert_equal("namespace My.App;", lines[1], "an empty existing file should get a skeleton")

-- Projects without RootNamespace fall back to the namespace in an existing source file.
local fallback_root = vim.fn.tempname() .. "-fallback-skeleton"
vim.fn.mkdir(fallback_root .. "/Models", "p")
vim.fn.mkdir(fallback_root .. "/src", "p")
vim.fn.mkdir(fallback_root .. "/bin", "p")
vim.fn.writefile({ "<Project></Project>" }, fallback_root .. "/Fallback.csproj")
vim.fn.writefile({ "// no namespace here" }, fallback_root .. "/A.cs")
vim.fn.writefile({ "namespace Wrong.Generated;" }, fallback_root .. "/bin/Generated.cs")
vim.fn.writefile({ "namespace Fallback.App;", "public class Existing {}" }, fallback_root .. "/src/Existing.cs")
lines = skeleton_of(fallback_root .. "/Models/Person.cs")
assert_equal("namespace Fallback.App.Models;", lines[1], "namespace should fall back to an existing source file")

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
vim.fn.delete(fallback_root, "rf")
print("csharp_new_file_spec: ok")
vim.cmd("qa!")
