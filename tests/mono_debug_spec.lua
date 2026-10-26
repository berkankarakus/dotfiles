local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n"), path)
end

local adapter_path = vim.fn.tempname() .. "-mono-debug/mono-debug.exe"
vim.env.NEO_MONO_DEBUG = adapter_path

require("lazy").load({ plugins = { "nvim-dap" } })
local dap = require("dap")

-- Breakpoints show as a red dot.
local sign = vim.fn.sign_getdefined("DapBreakpoint")[1]
assert_equal("●", vim.trim(sign.text), "the breakpoint sign should be a dot")
assert_equal("DapBreakpoint", sign.texthl, "the breakpoint sign should use its own highlight")
assert_equal(0xf7768e, vim.api.nvim_get_hl(0, { name = "DapBreakpoint" }).fg, "the breakpoint dot should be red")
local conditional = vim.fn.sign_getdefined("DapBreakpointCondition")[1]
assert_equal("◆", vim.trim(conditional.text), "a conditional breakpoint should be a diamond")
assert_equal("DapBreakpoint", conditional.texthl, "a conditional breakpoint should be red too")
local rejected = vim.fn.sign_getdefined("DapBreakpointRejected")[1]
assert_equal("○", vim.trim(rejected.text), "a rejected breakpoint should be a hollow circle")
assert_equal("DapBreakpointRejected", rejected.texthl, "a rejected breakpoint should use its own highlight")
assert_equal(0x8a4b55, vim.api.nvim_get_hl(0, { name = "DapBreakpointRejected" }).fg, "a rejected breakpoint should be a muted red")

-- The adapter runs mono-debug.exe under Mono, wherever NEO_MONO_DEBUG points.
local adapter
dap.adapters.mono(function(definition) adapter = definition end)
assert_equal("executable", adapter.type, "the Mono adapter is a stdio adapter")
assert_equal("mono", adapter.command, "the adapter runs under mono")
assert_equal(adapter_path, adapter.args[1], "the adapter should be mono-debug.exe from the configured path")
assert_equal("coreclr", dap.configurations.cs[1].type, "ordinary projects stay on coreclr by default")

-- F5 picks the debugger from the project.
local continued, notes = 0, {}
dap.continue = function() continued = continued + 1 end
vim.notify = function(message, level) notes[#notes + 1] = { message = message, level = level } end
local function f5() vim.fn.maparg("<F5>", "n", false, true).callback() end
local function open_in(directory, file)
  vim.cmd("cd " .. vim.fn.fnameescape(directory))
  vim.cmd("silent! %bwipeout!")
  vim.cmd("edit " .. vim.fn.fnameescape(directory .. "/" .. file))
end

local framework = vim.uv.fs_realpath(vim.fn.tempname() .. "-fx") or vim.fn.tempname() .. "-fx"
write(framework .. "/App.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net48</TargetFramework></PropertyGroup></Project>')
write(framework .. "/bin/Debug/net48/App.exe", "exe")
open_in(framework, "Program.cs")

f5()
assert_equal(0, continued, "F5 must not start without the Mono adapter")
assert_equal(1, #notes, "a missing adapter should be reported")
assert_equal(vim.log.levels.ERROR, notes[1].level, "the missing adapter is an error")
assert(notes[1].message:find(adapter_path, 1, true), "the message should name the expected path: " .. notes[1].message)

write(adapter_path, "adapter")
f5()
assert_equal(1, continued, "F5 should start debugging once the adapter exists")
local configuration = dap.configurations.cs[1]
assert_equal("mono", configuration.type, "a Framework project should use the Mono debugger")
assert_equal("launch", configuration.request, "the Mono configuration launches the program")
assert(vim.uv.fs_realpath(configuration.program()):find("bin/Debug/net48/App.exe", 1, true), "the program should be the built exe")
assert_equal(false, configuration.externalConsole, "output should stay inside Neovim")

local plain = vim.fn.tempname() .. "-plain"
write(plain .. "/Plain.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>')
write(plain .. "/bin/Debug/net10.0/Plain.dll", "dll")
write(plain .. "/bin/Debug/net10.0/Plain.runtimeconfig.json", "{}")
open_in(plain, "Program.cs")
f5()
assert_equal(2, continued, "F5 should start for an ordinary project as well")
assert_equal("coreclr", dap.configurations.cs[1].type, "an ordinary project goes back to coreclr")
assert_equal(1, #notes, "an ordinary project needs no Mono adapter")

vim.env.NEO_MONO_DEBUG = nil
print("mono_debug_spec: ok")
