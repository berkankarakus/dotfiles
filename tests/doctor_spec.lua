local doctor = require("neo.doctor")

local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

-- ------------------------------------------------------------------- Roslyn
assert_equal("5.12.0-1.26426.8", doctor.pinned_roslyn('#!/usr/bin/env bash\nset -e\n\nROSLYN_VERSION="5.12.0-1.26426.8"\nWITH_ELM=true\n'), "pinned version is read from the script")
assert_equal(nil, doctor.pinned_roslyn("echo nothing pinned"), "no pin means nil")

local listing = table.concat({
  "Package Id                  Version               Commands",
  "-----------------------------------------------------------------------------",
  "dotnet-ef                   9.0.0                 dotnet-ef",
  "roslyn-language-server      5.12.0-1.26426.8      roslyn-language-server",
}, "\n")
assert_equal("5.12.0-1.26426.8", doctor.installed_roslyn(listing), "installed version comes from the tool list")
assert_equal(nil, doctor.installed_roslyn("Package Id  Version  Commands\n----\ndotnet-ef 9.0.0 dotnet-ef"), "not installed")

assert_equal("ok", doctor.roslyn_check("1.0", "1.0").status, "matching versions are ok")
local drift = doctor.roslyn_check("1.0", "2.0")
assert_equal("warn", drift.status, "a different version is a warning")
assert(drift.detail:find("installed 2.0, pinned 1.0", 1, true), "the warning names both versions: " .. drift.detail)
assert_equal("fail", doctor.roslyn_check("1.0", nil).status, "missing server is a failure")
assert_equal("warn", doctor.roslyn_check(nil, "1.0").status, "an unknown pin is a warning")

-- ------------------------------------------------------------------ plugins
local lock = { alpha = { commit = "1111111aaaa" }, beta = { commit = "2222222bbbb" }, gamma = { commit = "3333333cccc" } }

local matching = doctor.lock_checks(lock, { alpha = "1111111aaaa", beta = "2222222bbbb", gamma = "3333333cccc" })
assert_equal(1, #matching, "one summary line when everything matches")
assert_equal("ok", matching[1].status, "all plugins at their locked commit")
assert(matching[1].detail:find("3 plugins", 1, true), "the summary counts plugins: " .. matching[1].detail)

local mixed = doctor.lock_checks(lock, { alpha = "1111111aaaa", beta = "9999999zzzz" })
assert_equal(2, #mixed, "a missing plugin and a drifted plugin give two lines")
assert_equal("fail", mixed[1].status, "missing plugins fail")
assert(mixed[1].detail:find("gamma", 1, true), "the missing plugin is named: " .. mixed[1].detail)
assert_equal("warn", mixed[2].status, "drifted plugins warn")
assert(mixed[2].detail:find("beta (installed 9999999, lock 2222222)", 1, true), "the drift names both commits: " .. mixed[2].detail)

-- ------------------------------------------------------------------- render
local lines = doctor.render({
  { status = "ok", label = "Neovim", detail = "0.12.5" },
  { status = "warn", label = "Roslyn language server", detail = "installed 2, pinned 1" },
  { status = "fail", label = "jq", detail = "not found" },
})
assert_equal("NeoDoctor", lines[1], "title")
assert(lines[3]:find("^%[ok  %] Neovim"), "ok line: " .. lines[3])
assert(lines[4]:find("^%[WARN%] Roslyn language server"), "warn line: " .. lines[4])
assert(lines[5]:find("^%[FAIL%] jq"), "fail line: " .. lines[5])
assert(lines[#lines]:find("1 ok, 1 warnings, 1 failures", 1, true), "summary line: " .. lines[#lines])

-- ------------------------------------------------------- the real command
assert_equal(2, vim.fn.exists(":NeoDoctor"), ":NeoDoctor should exist")
vim.cmd("NeoDoctor")
assert_equal("neo-doctor", vim.bo.filetype, "the report opens in its own buffer")
assert_equal(false, vim.bo.modifiable, "the report is read-only")
local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
for _, expected in ipairs({ "Neovim", "Roslyn language server", "Plugins", "dotnet", "Tree-sitter parser: c_sharp", "netcoredbg debugger", "ok," }) do
  assert(report:find(expected, 1, true), "the report should mention " .. expected .. ":\n" .. report)
end
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.bo.filetype ~= "neo-doctor", "q should close the report")

print("doctor_spec: ok")
vim.cmd("qa!")
