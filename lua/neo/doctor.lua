-- :NeoDoctor reports whether this machine matches what the config expects: the pinned Roslyn
-- version, plugins at the commits in lazy-lock.json, required tools, parsers and the debugger.
-- Run it on two machines and compare the output when they behave differently.
local M = {}

local STATUS = { ok = "ok", warn = "WARN", fail = "FAIL" }

local function check(status, label, detail) return { status = status, label = label, detail = detail } end

-- ---------------------------------------------------------------------- Roslyn
-- ROSLYN_VERSION in bootstrap-macos.sh is the single source of the pinned version.
function M.pinned_roslyn(script_text)
  return script_text:match('\nROSLYN_VERSION="([^"]+)"') or script_text:match('^ROSLYN_VERSION="([^"]+)"')
end

-- Parses the table printed by `dotnet tool list -g`.
function M.installed_roslyn(tool_list)
  for line in tool_list:gmatch("[^\n]+") do
    local name, version = line:match("^(%S+)%s+(%S+)")
    if name == "roslyn-language-server" then return version end
  end
end

function M.roslyn_check(pinned, installed)
  if not installed then return check("fail", "Roslyn language server", "not installed (dotnet tool install -g roslyn-language-server)") end
  if not pinned then return check("warn", "Roslyn language server", installed .. " (pinned version unknown: bootstrap-macos.sh not found)") end
  if installed ~= pinned then
    return check("warn", "Roslyn language server", string.format("installed %s, pinned %s", installed, pinned))
  end
  return check("ok", "Roslyn language server", installed)
end

-- --------------------------------------------------------------------- plugins
-- `lock` is the decoded lazy-lock.json, `heads` maps plugin name -> installed commit (nil if missing).
function M.lock_checks(lock, heads)
  local names = vim.tbl_keys(lock)
  table.sort(names)
  local missing, drifted = {}, {}
  for _, name in ipairs(names) do
    local wanted, actual = lock[name].commit, heads[name]
    if not actual then
      missing[#missing + 1] = name
    elseif actual ~= wanted then
      drifted[#drifted + 1] = string.format("%s (installed %s, lock %s)", name, actual:sub(1, 7), wanted:sub(1, 7))
    end
  end

  local results = {}
  if #missing > 0 then
    results[#results + 1] = check("fail", "Plugins installed", "missing: " .. table.concat(missing, ", "))
  end
  if #drifted > 0 then
    results[#results + 1] = check("warn", "Plugins match lazy-lock.json", table.concat(drifted, "; "))
  end
  if #missing == 0 and #drifted == 0 then
    results[#results + 1] = check("ok", "Plugins match lazy-lock.json", #names .. " plugins at their locked commits")
  end
  return results
end

local function plugin_checks()
  local lock_path = vim.fn.stdpath("config") .. "/lazy-lock.json"
  local read_ok, lines = pcall(vim.fn.readfile, lock_path)
  if not read_ok then return { check("warn", "Plugins match lazy-lock.json", "lazy-lock.json not found") } end
  local decode_ok, lock = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok then return { check("warn", "Plugins match lazy-lock.json", "lazy-lock.json is not valid JSON") } end

  local root = require("lazy.core.config").options.root
  local heads = {}
  for name in pairs(lock) do
    local result = vim.system({ "git", "-C", root .. "/" .. name, "rev-parse", "HEAD" }, { text = true }):wait(5000)
    if result.code == 0 then heads[name] = vim.trim(result.stdout) end
  end
  return M.lock_checks(lock, heads)
end

-- ------------------------------------------------------------------ the rest
local function run(command)
  local ok, process = pcall(vim.system, command, { text = true })
  if not ok then return nil end
  local result = process:wait(8000)
  if result.code ~= 0 then return nil end
  return vim.trim((result.stdout or "") .. (result.stderr or ""))
end

local function roslyn_check()
  local script_ok, script = pcall(vim.fn.readfile, vim.fn.stdpath("config") .. "/bootstrap-macos.sh")
  local pinned = script_ok and M.pinned_roslyn("\n" .. table.concat(script, "\n")) or nil
  local listing = vim.fn.executable("dotnet") == 1 and run({ "dotnet", "tool", "list", "-g" }) or nil
  return M.roslyn_check(pinned, listing and M.installed_roslyn(listing) or nil)
end

local function tool_checks()
  local results = {}
  -- required: the config breaks without them; optional: a feature is lost.
  local tools = {
    { "dotnet", true }, { "git", true }, { "rg", true }, { "fd", true }, { "tree-sitter", true },
    { "jq", false }, { "terminal-notifier", false },
  }
  for _, tool in ipairs(tools) do
    local path = vim.fn.exepath(tool[1])
    if path ~= "" then
      results[#results + 1] = check("ok", tool[1], path)
    else
      results[#results + 1] = check(tool[2] and "fail" or "warn", tool[1], tool[2] and "not found" or "not found (optional)")
    end
  end
  return results
end

local function parser_checks()
  local results = {}
  local parser_dir = vim.fn.stdpath("data") .. "/site/parser/"
  local languages = { "c_sharp", "mssql", "json" }
  if vim.fn.executable("elm") == 1 then languages[#languages + 1] = "elm" end
  for _, language in ipairs(languages) do
    local present = vim.uv.fs_stat(parser_dir .. language .. ".so") ~= nil
    results[#results + 1] = check(present and "ok" or "fail", "Tree-sitter parser: " .. language, present and "installed" or "missing")
  end
  return results
end

local function debugger_check()
  local path = vim.fn.stdpath("data") .. "/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
  local present = vim.fn.executable(path) == 1
  return check(present and "ok" or "fail", "netcoredbg debugger", present and path or "not found: " .. path)
end

local function terminal_check()
  local ghostty = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
  local version = vim.fn.executable(ghostty) == 1 and run({ ghostty, "--version" }) or nil
  local first_line = version and version:match("[^\n]+") or nil
  local program = vim.env.TERM_PROGRAM or "unknown"
  if first_line then return check("ok", "Terminal", program .. ", " .. first_line) end
  return check("warn", "Terminal", program .. " (Ghostty not found)")
end

local function neovim_check()
  local version = vim.version()
  return check("ok", "Neovim", string.format("%d.%d.%d", version.major, version.minor, version.patch))
end

-- Collects every check. Slow checks (dotnet, one git call per plugin) run synchronously on purpose:
-- this is an on-demand report, not something on the startup path.
function M.collect()
  local results = { neovim_check(), terminal_check(), roslyn_check() }
  vim.list_extend(results, plugin_checks())
  vim.list_extend(results, tool_checks())
  vim.list_extend(results, parser_checks())
  results[#results + 1] = debugger_check()
  return results
end

function M.render(results)
  local width = 0
  for _, item in ipairs(results) do width = math.max(width, #item.label) end
  local counts = { ok = 0, warn = 0, fail = 0 }
  local lines = { "NeoDoctor", "" }
  for _, item in ipairs(results) do
    counts[item.status] = counts[item.status] + 1
    lines[#lines + 1] = string.format("[%-4s] %-" .. width .. "s  %s", STATUS[item.status], item.label, item.detail)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("%d ok, %d warnings, %d failures    (q closes this window)", counts.ok, counts.warn, counts.fail)
  return lines
end

function M.report()
  return M.render(M.collect())
end

function M.open()
  local lines = M.report()
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "neo-doctor"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true, desc = "Close NeoDoctor" })
end

function M.setup()
  vim.api.nvim_create_user_command("NeoDoctor", function() M.open() end, {
    desc = "Check this machine against the config's expectations",
  })
end

return M
