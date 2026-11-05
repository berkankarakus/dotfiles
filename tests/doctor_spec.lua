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

-- ---------------------------------------------------- plugins, verbose list
local verbose = doctor.lock_checks(lock, { alpha = "1111111aaaa", beta = "9999999zzzz" }, true)
assert_equal(3, #verbose, "verbose mode lists every plugin")
assert_equal("ok", verbose[1].status, "alpha is at its locked commit")
assert_equal("1111111", verbose[1].detail, "the installed commit is shown")
assert_equal("warn", verbose[2].status, "beta drifted")
assert_equal("fail", verbose[3].status, "gamma is missing")

-- ------------------------------------------------------------ deployed files
local diff = doctor.first_difference({ "a", "b", "c" }, { "a", "x", "c" })
assert_equal(2, diff.line, "the first differing line")
assert_equal("b", diff.left, "left side")
assert_equal("x", diff.right, "right side")
assert_equal(nil, doctor.first_difference({ "a" }, { "a" }), "equal files have no difference")
assert_equal(3, doctor.first_difference({ "a", "b" }, { "a", "b", "c" }).line, "a longer file differs at its first extra line")

assert_equal("ok", doctor.file_check("zsh config", { "a" }, { "a" }, "templates/x").status, "identical files are ok")
local drifted = doctor.file_check("zsh config", { "bindkey '^G' autosuggest-clear" }, { "bindkey '^G' autosuggest-accept" }, "templates/neovim-csharp.zsh")
assert_equal("warn", drifted.status, "a deployed file that differs from its template warns")
assert(drifted.detail:find("line 1", 1, true) and drifted.detail:find("autosuggest-accept", 1, true) and drifted.detail:find("autosuggest-clear", 1, true),
  "the warning shows the line and both versions: " .. drifted.detail)
assert_equal("fail", doctor.file_check("zsh config", { "a" }, nil, "templates/x").status, "a file that was never deployed fails")
assert_equal("warn", doctor.file_check("zsh config", nil, { "a" }, "templates/x").status, "a missing template warns")

-- ------------------------------------------------------------------- Ghostty
local template = {
  "# comment",
  "theme = TokyoNight Moon",
  "macos-option-as-alt = true",
  "window-decoration = auto",
  "keybind = option+backspace=text:\\x17",
  "keybind = command+arrow_left=csi:H",
}
local effective = table.concat({
  "theme = TokyoNight Moon",
  "macos-option-as-alt = true",
  "keybind = alt+backspace=text:\\\\x17",
  "keybind = super+arrow_left=csi:H",
}, "\n")
local defaults = "window-decoration = auto\nmacos-option-as-alt = \ntheme = \n"
assert_equal(0, #doctor.ghostty_mismatches(template, effective, defaults),
  "option/command, escaped backslashes and a setting that is still at its default all count as applied")

local not_applied = doctor.ghostty_mismatches(template, effective:gsub("macos%-option%-as%-alt = true\n", ""), defaults)
assert_equal(1, #not_applied, "a setting Ghostty does not apply is reported (this is how a missing Option-as-Alt shows up)")
assert_equal("macos-option-as-alt = true", not_applied[1], "it names the setting")

local overridden = doctor.ghostty_mismatches({ "window-decoration = auto" }, "window-decoration = none", defaults)
assert_equal(1, #overridden, "a default value does not count when the key is overridden to something else")
assert_equal(1, #doctor.ghostty_mismatches({ "keybind = option+delete=esc:d" }, effective, defaults), "a missing keybind is reported")

-- ------------------------------------------------------------------- render
local lines = doctor.render({
  { section = "Environment", status = "ok", label = "Neovim", detail = "0.12.5" },
  { section = "Tools", status = "warn", label = "Roslyn language server", detail = "installed 2, pinned 1" },
  { section = "Tools", status = "fail", label = "jq", detail = "not found" },
  { section = "Tools", status = "info", label = "elm", detail = "not installed" },
})
assert_equal("NeoDoctor", lines[1], "title")
assert_equal("Environment", lines[3], "a section header precedes its items")
assert(lines[4]:find("^%[ok  %] Neovim"), "ok line: " .. lines[4])
assert_equal("Tools", lines[6], "the next section gets its own header")
assert(lines[7]:find("^%[WARN%] Roslyn language server"), "warn line: " .. lines[7])
assert(lines[8]:find("^%[FAIL%] jq"), "fail line: " .. lines[8])
assert(lines[9]:find("^%[info%] elm"), "info line: " .. lines[9])
assert(lines[#lines]:find("1 ok, 1 warnings, 1 failures, 1 not installed (info)", 1, true), "summary line: " .. lines[#lines])

-- A symlinked original: linked, ordinary file, wrong target, broken link, missing.
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local original = directory .. "/original.md"
local other = directory .. "/other.md"
vim.fn.writefile({ "x" }, original)
vim.fn.writefile({ "y" }, other)
local link = directory .. "/link.md"

vim.uv.fs_symlink(original, link)
assert_equal("ok", doctor.symlink_check("link", link, original, "templates/x").status, "a link to the original is ok")

vim.fn.delete(link)
vim.uv.fs_symlink(other, link)
local wrong = doctor.symlink_check("link", link, original, "templates/x")
assert_equal("warn", wrong.status, "a link to another file warns")
assert(wrong.detail:find("other.md", 1, true), "the warning names the actual target: " .. wrong.detail)

vim.fn.delete(link)
vim.fn.writefile({ "x" }, link)
local ordinary = doctor.symlink_check("link", link, original, "templates/x")
assert_equal("warn", ordinary.status, "a link replaced by an ordinary file warns")
assert(ordinary.detail:find("no longer linked", 1, true), "the warning says the link is gone: " .. ordinary.detail)

vim.fn.delete(link)
vim.uv.fs_symlink(directory .. "/gone.md", link)
assert_equal("warn", doctor.symlink_check("link", link, original, "templates/x").status, "a broken link warns")

vim.fn.delete(link)
assert_equal("warn", doctor.symlink_check("link", link, original, "templates/x").status, "a missing link warns")
vim.fn.delete(directory, "rf")

-- ------------------------------------------------------- the real command
assert_equal(2, vim.fn.exists(":NeoDoctor"), ":NeoDoctor should exist")
vim.cmd("NeoDoctor")
assert_equal("neo-doctor", vim.bo.filetype, "the report opens in its own buffer")
assert_equal(false, vim.bo.modifiable, "the report is read-only")
local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
for _, expected in ipairs({
  "Environment", "Deployed files", "Ghostty", "Tools", "Plugins", "Parsers and debugger",
  "Neovim", "macOS", "zsh config", "Ghostty config", "~/.claude/CLAUDE.md link", "~/.zshrc sources the zsh config", "zsh-autosuggestions",
  "Second Ghostty config", "Ghostty applied settings", "Roslyn language server", "dotnet", "Plugins match lazy-lock.json",
  "Tree-sitter parser: c_sharp", "netcoredbg debugger", "ok,",
}) do
  assert(report:find(expected, 1, true), "the report should mention " .. expected .. ":\n" .. report)
end
if vim.uv.fs_stat(vim.fn.expand("~/.codex")) then
  assert(report:find("~/.codex/AGENTS.md link", 1, true), "the report should check the Codex instructions link:\n" .. report)
end
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.bo.filetype ~= "neo-doctor", "q should close the report")

-- :NeoDoctor! lists every plugin from the lock file.
vim.cmd("NeoDoctor!")
local detailed = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(detailed:find("nvim-treesitter", 1, true) and detailed:find("oil.nvim", 1, true), "the bang form lists every plugin:\n" .. detailed)
assert(not detailed:find("Plugins match lazy-lock.json", 1, true), "the bang form replaces the one-line summary")
vim.api.nvim_feedkeys("q", "x", false)

-- ------------------------------------------------------------- concurrency
-- ~50 short processes run one after the other took seconds; every one of them must be started before the
-- first result is waited for, so the report takes about as long as the slowest process.
local events = {}
local original_system = vim.system
vim.system = function(command)
  events[#events + 1] = "start"
  return {
    wait = function()
      events[#events + 1] = "wait"
      return { code = 0, stdout = "tool 1.0\n", stderr = "" }
    end,
  }
end
doctor.collect()
vim.system = original_system

local started_before_first_wait = 0
for _, event in ipairs(events) do
  if event == "wait" then break end
  started_before_first_wait = started_before_first_wait + 1
end
local total_started = 0
for _, event in ipairs(events) do
  if event == "start" then total_started = total_started + 1 end
end
assert(total_started >= 30, "the report should run many processes (one git call per plugin and tool versions), got " .. total_started)
assert_equal(total_started, started_before_first_wait, "every process must be started before the first one is waited for")

print("doctor_spec: ok")
vim.cmd("qa!")
