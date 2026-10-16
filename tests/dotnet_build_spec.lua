local build = require("neo.dotnet_build")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n"), path)
end

local root = vim.uv.fs_realpath(vim.fn.tempname() .. "-build") or vim.fn.tempname() .. "-build"
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)

-- ---------------------------------------------------------------- find_target
write(root .. "/Both/App.sln", "sln")
write(root .. "/Both/Src/App.csproj", "<Project/>")
write(root .. "/Both/Src/Deep/File.cs", "class A {}")
assert_equal(root .. "/Both/App.sln", build.find_target(root .. "/Both/Src/Deep"), "the solution should win over the project")

write(root .. "/Slnx/App.slnx", "slnx")
assert_equal(root .. "/Slnx/App.slnx", build.find_target(root .. "/Slnx"), ".slnx solutions should be found")

write(root .. "/OnlyProject/Lib/Lib.csproj", "<Project/>")
assert_equal(root .. "/OnlyProject/Lib/Lib.csproj", build.find_target(root .. "/OnlyProject/Lib"), "a project alone is the fallback")

vim.fn.mkdir(root .. "/Nothing/Here", "p")
assert_equal(nil, build.find_target(root .. "/Nothing/Here"), "no target above the directory")

-- --------------------------------------------------------------------- parse
-- MSBuild prints every diagnostic twice, in different orders, and trails the project in brackets.
local program = root .. "/Both/Src/Program.cs"
local other = root .. "/Both/Src/Sub/Other.cs"
write(program, "class P\n{\n    static void Main()\n    {\n        int unused;\n        string s = 5;\n    }\n}")
write(other, "class Other\n{\n    int Unused(string a) { return a; }\n}")
local project = root .. "/Both/Src/App.csproj"
local lines = {
  program .. "(6,20): error CS0029: Cannot implicitly convert type 'int' to 'string' [" .. project .. "]",
  program .. "(5,13): warning CS0168: The variable 'unused' is declared but never used [" .. project .. "]",
  other .. "(3,35): error CS0029: Cannot implicitly convert type 'string' to 'int' [" .. project .. "]",
  "",
  "Build FAILED.",
  "",
  program .. "(5,13): warning CS0168: The variable 'unused' is declared but never used [" .. project .. "]",
  program .. "(6,20): error CS0029: Cannot implicitly convert type 'int' to 'string' [" .. project .. "]",
  other .. "(3,35): error CS0029: Cannot implicitly convert type 'string' to 'int' [" .. project .. "]",
  "    1 Warning(s)",
  "    2 Error(s)",
  "Time Elapsed 00:00:01.90",
}
local items, errors, warnings = build.parse(lines)
assert_equal(3, #items, "duplicate diagnostics should be dropped")
assert_equal(2, errors, "two errors")
assert_equal(1, warnings, "one warning")
assert_equal("E", items[1].type:upper(), "the first diagnostic is an error")
assert_equal(6, items[1].lnum, "line number")
assert_equal(20, items[1].col, "column")
assert_equal("CS0029: Cannot implicitly convert type 'int' to 'string'", vim.trim(items[1].text),
  "the error code stays and the trailing [project] is stripped from the text")
assert_equal(program, vim.uv.fs_realpath(vim.api.nvim_buf_get_name(items[1].bufnr)), "the item should point at the file")
assert_equal("W", items[2].type:upper(), "the second diagnostic is a warning")
assert_equal(other, vim.uv.fs_realpath(vim.api.nvim_buf_get_name(items[3].bufnr)), "files in subfolders are resolved too")

local none = build.parse({ "Build succeeded.", "    0 Warning(s)", "    0 Error(s)" })
assert_equal(0, #none, "plain output has no diagnostics")

-- ------------------------------------------------------- build (fake process)
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level) notifications[#notifications + 1] = { message = message, level = level } end

local original_run = build.run
local commands = {}
local function fake(result)
  build.run = function(command, cwd, on_exit)
    commands[#commands + 1] = { command = command, cwd = cwd }
    on_exit(result)
  end
end

local function qf_window_open() return vim.fn.getqflist({ winid = 0 }).winid ~= 0 end
local function last_note() return notifications[#notifications] end

vim.cmd("silent edit " .. vim.fn.fnameescape(program))

-- Failure with diagnostics: the quickfix list is filled and opened.
fake({ code = 1, stdout = table.concat(lines, "\n"), stderr = "" })
local done
build.build(function(summary) done = summary end)
assert_equal(root .. "/Both/App.sln", commands[1].command[3], "the solution above the file should be built")
assert_equal(root .. "/Both", commands[1].cwd, "the build should run from the target's directory")
assert_equal("dotnet", commands[1].command[1], "dotnet build")
assert_equal(2, done.errors, "two errors reported")
assert_equal(3, vim.fn.getqflist({ size = 0 }).size, "all diagnostics land in the quickfix list")
assert(qf_window_open(), "the quickfix window should open on errors")
assert_equal(vim.log.levels.ERROR, last_note().level, "failure is an error notification")
assert(last_note().message:find("2 errors, 1 warning", 1, true), "the notification should count them: " .. last_note().message)

-- Success with a warning, started from the quickfix window that the failed build left focused: the
-- window has no file of its own, so the target of the previous build is reused.
assert_equal("qf", vim.bo.filetype, "the failed build leaves the quickfix window focused")
fake({ code = 0, stdout = lines[2], stderr = "" })
build.build()
assert_equal(root .. "/Both/App.sln", commands[#commands].command[3], "rebuilding from the quickfix window reuses the last target")
assert(not qf_window_open(), "no quickfix window on success")
assert_equal(vim.log.levels.WARN, last_note().level, "success with warnings is a warning")
assert_equal(1, vim.fn.getqflist({ size = 0 }).size, "the warning stays in the list")

-- Clean success.
fake({ code = 0, stdout = "Build succeeded.\n    0 Warning(s)\n    0 Error(s)", stderr = "" })
build.build()
assert_equal("Build succeeded.", last_note().message, "clean success")
assert_equal(0, vim.fn.getqflist({ size = 0 }).size, "a clean build empties the list")

-- Failure without any file position (missing project, restore error): show the output tail.
fake({ code = 1, stdout = "", stderr = "MSBUILD : error MSB1009: Project file does not exist.\nSwitch: Nope.csproj" })
build.build()
assert_equal(vim.log.levels.ERROR, last_note().level, "a positionless failure is still an error")
assert(last_note().message:find("MSB1009", 1, true), "the output tail should be shown: " .. last_note().message)

-- A second build while one is running is refused.
local pending
build.run = function(_, _, on_exit) pending = on_exit end
build.build()
build.build()
assert_equal("dotnet build is already running.", last_note().message, "concurrent builds are refused")
pending({ code = 0, stdout = "Build succeeded.", stderr = "" })

-- No project at all (and nothing built before).
build.last_target = nil
vim.cmd("silent enew")
vim.cmd.cd(root .. "/Nothing/Here")
local before = #commands
fake({ code = 0, stdout = "", stderr = "" })
build.build()
assert_equal(before, #commands, "nothing should run without a target")
assert(last_note().message:find("No .sln", 1, true), "the user should be told why: " .. last_note().message)

build.run = original_run
vim.notify = original_notify

-- ------------------------------------------------------------ real dotnet run
if vim.fn.executable("dotnet") == 1 then
  local project_dir = root .. "/Real"
  write(project_dir .. "/Real.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>')
  write(project_dir .. "/Program.cs", "class P\n{\n    static void Main()\n    {\n        string s = 5;\n    }\n}")
  vim.cmd("silent edit " .. vim.fn.fnameescape(project_dir .. "/Program.cs"))
  vim.notify = function() end

  local summary
  build.build(function(result) summary = result end)
  vim.wait(60000, function() return summary ~= nil end, 100)
  vim.notify = original_notify

  assert(summary, "the real dotnet build should finish")
  assert(summary.errors >= 1, "the real build should report the type error")
  local first = vim.fn.getqflist()[1]
  assert_equal(5, first.lnum, "the real error line")
  assert(first.text:find("CS0029", 1, true) or first.text:find("convert", 1, true), "the real error text: " .. first.text)
end

-- ------------------------------------------------------------------- mapping
local mapping = vim.fn.maparg(" rb", "n", false, true)
assert(mapping.lhs and mapping.lhs ~= "", "<leader>rb should be mapped")
assert_equal(2, vim.fn.exists(":DotnetBuild"), ":DotnetBuild should exist")

vim.cmd.cd("/")
vim.fn.delete(root, "rf")
print("dotnet_build_spec: ok")
vim.cmd("qa!")
