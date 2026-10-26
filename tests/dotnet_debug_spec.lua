vim.opt.rtp:prepend(vim.fn.getcwd())

local debug = require("neo.dotnet_debug")

local function assert_equal(expected, actual, message)
  if expected ~= actual then error((message or "values differ") .. string.format(" (expected %s, got %s)", vim.inspect(expected), vim.inspect(actual)), 0) end
end

local resolves = 0
local cache = debug.launch_context_cache(function()
  resolves = resolves + 1
  return { project_file = "App.csproj", program = "App.dll" }
end)

assert_equal("App.dll", cache.get().program, "first lookup should resolve the launch context")
assert_equal("App.csproj", cache.get().project_file, "subsequent lookup should reuse the launch context")
assert_equal(1, resolves, "launch context should be resolved once per debug session")

cache.reset()
cache.get()
assert_equal(2, resolves, "a new debug session should resolve a fresh launch context")

local nil_resolves = 0
local nil_cache = debug.launch_context_cache(function()
  nil_resolves = nil_resolves + 1
  return nil
end)
assert_equal(nil, nil_cache.get(), "nil launch contexts should be supported")
assert_equal(nil, nil_cache.get(), "nil launch contexts should be cached too")
assert_equal(1, nil_resolves, "nil launch context should not trigger repeated resolution")

-- Project discovery and launch profile parsing (moved here from the DAP plugin config).
local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n"), path)
end
local function real(path) return path and vim.uv.fs_realpath(path) or path end

local root = real(vim.fn.tempname() .. "-dotnet")
vim.fn.mkdir(root, "p")
root = real(root)
write(root .. "/App.sln", "Microsoft Visual Studio Solution File")
write(root .. "/Lib/Lib.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup></PropertyGroup></Project>')
write(root .. "/Web/Web.csproj", '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>')
write(root .. "/Cli/Cli.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType></PropertyGroup></Project>')
write(root .. "/Worker/Worker.csproj", '<Project Sdk="Microsoft.NET.Sdk.Worker"></Project>')
write(root .. "/Web/Properties/launchSettings.json", vim.json.encode({
  profiles = {
    IIS = { commandName = "IISExpress" },
    Web = {
      commandName = "Project",
      applicationUrl = "http://localhost:5000;https://localhost:5001",
      launchBrowser = true,
      launchUrl = "swagger",
      environmentVariables = { ASPNETCORE_ENVIRONMENT = "Development" },
    },
  },
}))
write(root .. "/Web/bin/Debug/net10.0/Web.dll", "dll")
write(root .. "/Web/bin/Debug/net10.0/Web.runtimeconfig.json", "{}")

assert_equal("Microsoft.NET.Sdk.Web", debug.project_sdk(root .. "/Web/Web.csproj"), "project_sdk should read the SDK attribute")
assert_equal("Microsoft.NET.Sdk", debug.project_sdk(root .. "/Lib/Lib.csproj"), "project_sdk should read plain SDK projects")
assert_equal(false, debug.project_sdk(nil), "project_sdk should handle a missing project")
assert_equal(false, debug.project_sdk(root .. "/missing.csproj"), "project_sdk should handle an unreadable project")

assert_equal(false, debug.project_is_executable(root .. "/Lib/Lib.csproj"), "libraries are not executable")
assert_equal(true, debug.project_is_executable(root .. "/Web/Web.csproj"), "web projects are executable")
assert_equal(true, debug.project_is_executable(root .. "/Cli/Cli.csproj"), "OutputType Exe is executable")
assert_equal(true, debug.project_is_executable(root .. "/Worker/Worker.csproj"), "worker services are executable")
assert_equal(false, debug.project_is_executable(nil), "a missing project is not executable")

vim.cmd.cd(root .. "/Web")
assert_equal(root .. "/Web/Web.csproj", real(debug.project_file()), "project_file should find the nearest csproj upward")
assert_equal(root .. "/Web/Web.csproj", real(debug.debug_project_file()), "an executable nearest project should be debugged directly")

vim.cmd.cd(root .. "/Lib")
assert_equal(root .. "/Lib/Lib.csproj", real(debug.project_file()), "project_file should find the library project")
-- The solution holds three executables (Web, Cli, Worker); drop two so exactly one remains.
vim.fn.delete(root .. "/Cli", "rf")
vim.fn.delete(root .. "/Worker", "rf")
assert_equal(root .. "/Web/Web.csproj", real(debug.debug_project_file()),
  "a library should fall back to the single executable project in the solution")

vim.fn.delete(root .. "/App.sln")
assert_equal(root .. "/Lib/Lib.csproj", real(debug.debug_project_file()),
  "without a solution the nearest project is used")

assert_equal(root .. "/Web/bin/Debug/net10.0/Web.dll", real(debug.program(root .. "/Web/Web.csproj")),
  "program should find the built DLL that has a runtimeconfig")

local profile = debug.launch_profile(root .. "/Web/Web.csproj")
assert_equal(root .. "/Web", profile.cwd, "the working directory should be the project directory")
assert_equal("Development", profile.env.ASPNETCORE_ENVIRONMENT, "profile environment variables should be kept")
assert_equal("http://localhost:5000;https://localhost:5001", profile.env.ASPNETCORE_URLS, "applicationUrl should become ASPNETCORE_URLS")
assert_equal("http://localhost:5000/swagger", profile.browser_url, "browser url should use the first URL and launchUrl")
assert_equal(0, #profile.args, "a profile without commandLineArgs has no arguments")

local no_settings = debug.launch_profile(root .. "/Lib/Lib.csproj")
assert_equal(root .. "/Lib", no_settings.cwd, "projects without launchSettings still get their directory")
assert_equal(nil, no_settings.browser_url, "projects without launchSettings open no browser")

assert_equal(vim.fn.getcwd(), debug.launch_profile(nil).cwd, "no project falls back to the current directory")

write(root .. "/Lib/Properties/launchSettings.json", "{ not json")
local warnings = {}
local original_notify = vim.notify
vim.notify = function(message, level) warnings[#warnings + 1] = { message = message, level = level } end
local broken = debug.launch_profile(root .. "/Lib/Lib.csproj")
vim.notify = original_notify
assert_equal(root .. "/Lib", broken.cwd, "invalid launchSettings should fall back to defaults")
assert_equal(1, #warnings, "invalid launchSettings should warn once")
assert_equal(vim.log.levels.WARN, warnings[1].level, "the warning should use WARN")

vim.cmd.cd(root .. "/Web")
local context = debug.resolve_launch_context()
assert_equal(root .. "/Web/bin/Debug/net10.0/Web.dll", real(context.program), "resolve_launch_context should combine program and profile")
assert_equal(root .. "/Web", context.profile.cwd, "resolve_launch_context should include the launch profile")

vim.cmd.cd("/")
vim.fn.delete(root, "rf")

-- .NET Framework projects: detection, the executable to debug and the launch context.
local function project(name, text)
  local path = root .. "/Framework/" .. name .. ".csproj"
  write(path, text)
  return path
end

assert_equal(true, debug.project_is_framework(project("Sdk48", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net48</TargetFramework></PropertyGroup></Project>')), "net48 should be a Framework project")
assert_equal(true, debug.project_is_framework(project("Sdk472", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net472</TargetFramework></PropertyGroup></Project>')), "net472 should be a Framework project")
assert_equal(true, debug.project_is_framework(project("Many", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFrameworks>net462;net48</TargetFrameworks></PropertyGroup></Project>')), "all-Framework target lists should count")
assert_equal(true, debug.project_is_framework(project("Old", '<Project ToolsVersion="15.0"><PropertyGroup><TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion></PropertyGroup></Project>')), "an old-style v4.7.2 project should be a Framework project")
assert_equal(false, debug.project_is_framework(project("Core", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>')), "net10.0 is not a Framework project")
assert_equal(false, debug.project_is_framework(project("Mixed", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFrameworks>net48;net8.0</TargetFrameworks></PropertyGroup></Project>')), "a list that includes .NET should not count")
assert_equal(false, debug.project_is_framework(project("Std", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>netstandard2.0</TargetFramework></PropertyGroup></Project>')), "netstandard is not a Framework project")
assert_equal(false, debug.project_is_framework(root .. "/Framework/Missing.csproj"), "a missing file is not a Framework project")
assert_equal(false, debug.project_is_framework(nil), "no project is not a Framework project")

-- SDK style: bin/Debug/<tfm>/<Name>.exe, the newest one wins.
local sdk_project = root .. "/Framework/Sdk48.csproj"
write(root .. "/Framework/bin/Debug/net472/Sdk48.exe", "old")
write(root .. "/Framework/bin/Debug/net48/Sdk48.exe", "new")
write(root .. "/Framework/bin/Debug/net48/Other.exe", "other")
vim.uv.fs_utime(root .. "/Framework/bin/Debug/net472/Sdk48.exe", 1000, 1000)
assert_equal(root .. "/Framework/bin/Debug/net48/Sdk48.exe", real(debug.framework_program(sdk_project)), "the newest build of the project's own exe should be debugged")

-- Old style: bin/Debug/<AssemblyName>.exe, the assembly name may differ from the project name.
local old_project = project("OldNamed", '<Project ToolsVersion="15.0"><PropertyGroup><AssemblyName>Shipped.App</AssemblyName><TargetFrameworkVersion>v4.8</TargetFrameworkVersion></PropertyGroup></Project>')
write(root .. "/Framework/bin/Debug/Shipped.App.exe", "exe")
assert_equal(root .. "/Framework/bin/Debug/Shipped.App.exe", real(debug.framework_program(old_project)), "an old-style project should use its AssemblyName and no target folder")

-- The launch context carries the Framework flag; ordinary projects do not.
vim.cmd("cd " .. vim.fn.fnameescape(root .. "/Framework"))
vim.cmd("silent! %bwipeout!")
vim.cmd("edit " .. vim.fn.fnameescape(root .. "/Framework/Program.cs"))
os.remove(root .. "/Framework/OldNamed.csproj")
os.remove(root .. "/Framework/Old.csproj")
os.remove(root .. "/Framework/Many.csproj")
os.remove(root .. "/Framework/Sdk472.csproj")
os.remove(root .. "/Framework/Core.csproj")
os.remove(root .. "/Framework/Mixed.csproj")
os.remove(root .. "/Framework/Std.csproj")
write(root .. "/Framework/Sdk48.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net48</TargetFramework></PropertyGroup></Project>')
local framework_context = debug.resolve_launch_context()
assert_equal(true, framework_context.framework, "a Framework project should flag the launch context")
assert_equal(root .. "/Framework/bin/Debug/net48/Sdk48.exe", real(framework_context.program), "the launch context should name the exe")
assert_equal(root .. "/Framework", framework_context.profile.cwd, "the launch context should run in the project directory")

write(root .. "/Plain/Plain.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>')
write(root .. "/Plain/bin/Debug/net10.0/Plain.dll", "dll")
write(root .. "/Plain/bin/Debug/net10.0/Plain.runtimeconfig.json", "{}")
vim.cmd("cd " .. vim.fn.fnameescape(root .. "/Plain"))
vim.cmd("silent! %bwipeout!")
vim.cmd("edit " .. vim.fn.fnameescape(root .. "/Plain/Program.cs"))
local plain_context = debug.resolve_launch_context()
assert_equal(nil, plain_context.framework, "an ordinary project must not be flagged")
assert_equal(root .. "/Plain/bin/Debug/net10.0/Plain.dll", real(plain_context.program), "an ordinary project still debugs its dll")

-- The adapter lives under the Neovim data directory unless NEO_MONO_DEBUG overrides it.
vim.env.NEO_MONO_DEBUG = nil
assert_equal(vim.fn.stdpath("data") .. "/mono-debug/mono-debug.exe", debug.mono_debug_path(), "the default adapter location")
vim.env.NEO_MONO_DEBUG = "/somewhere/mono-debug.exe"
assert_equal("/somewhere/mono-debug.exe", debug.mono_debug_path(), "NEO_MONO_DEBUG should override the location")
vim.env.NEO_MONO_DEBUG = nil

print("dotnet_debug_spec: ok")
