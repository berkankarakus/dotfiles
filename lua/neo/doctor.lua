-- :NeoDoctor lists everything this config depends on and whether this machine matches it, so two
-- machines can be compared line by line: the environment, the files the bootstrap deploys (against the
-- templates in the repo), the settings Ghostty really applies, tools with their versions, plugins at their
-- locked commits, parsers and the debugger. `:NeoDoctor!` also lists every plugin with its commit.
local M = {}
local checks = require("neo.doctor.checks")

local STATUS = { ok = "ok", warn = "WARN", fail = "FAIL", info = "info" }

local function check(section, status, label, detail)
  return { section = section, status = status, label = label, detail = detail }
end

local function config_path(relative) return vim.fn.stdpath("config") .. "/" .. relative end
local function home(relative) return vim.fn.expand("~") .. "/" .. relative end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or nil
end

-- The report needs ~50 short processes (tool versions, one `git rev-parse` per plugin). Run one after
-- the other they add up to seconds, so `collect` first starts all of them at once (`prefetch`) and the
-- checks then just read the results: the report takes about as long as the slowest process.
local jobs = {}

local function job_key(command) return table.concat(command, "\0") end

local function start(command)
  local key = job_key(command)
  if jobs[key] ~= nil then return end
  local ok, process = pcall(vim.system, command, { text = true })
  jobs[key] = ok and { process = process } or { failed = true }
end

-- Runs a command (or reuses the one prefetch started) and returns its trimmed output, or nil when it is
-- missing or fails.
local function run(command)
  start(command)
  local job = jobs[job_key(command)]
  if job.failed then return nil end
  if not job.result then job.result = job.process:wait(8000) end
  if job.result.code ~= 0 then return nil end
  return vim.trim((job.result.stdout or "") .. (job.result.stderr or ""))
end

local function first_line(text) return text and text:match("[^\n]+") or nil end

-- Pure report checks live separately so this module only orchestrates the machine-wide collection.
M.pinned_roslyn = checks.pinned_roslyn
M.installed_roslyn = checks.installed_roslyn
M.roslyn_check = checks.roslyn_check
M.lock_checks = checks.lock_checks
M.first_difference = checks.first_difference
M.file_check = checks.file_check
M.symlink_check = checks.symlink_check
M.ghostty_mismatches = checks.ghostty_mismatches
local shorten = checks.shorten

-- Decoded lazy-lock.json, or nil plus the reason a check line should give.
local function read_lock()
  local lines = read_lines(config_path("lazy-lock.json"))
  if not lines then return nil, "lazy-lock.json not found" end
  local decode_ok, lock = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok then return nil, "lazy-lock.json is not valid JSON" end
  return lock
end

local function head_command(name)
  return { "git", "-C", require("lazy.core.config").options.root .. "/" .. name, "rev-parse", "HEAD" }
end

local function plugin_checks(verbose)
  local lock, problem = read_lock()
  if not lock then return { check("Plugins", "warn", "Plugins match lazy-lock.json", problem) } end
  local heads = {}
  for name in pairs(lock) do heads[name] = run(head_command(name)) end
  return M.lock_checks(lock, heads, verbose)
end

-- --------------------------------------------------------------- deployed files
local function deployed_file_checks()
  local results = {
    M.file_check("zsh config", read_lines(config_path("templates/neovim-csharp.zsh")),
      read_lines(home(".config/zsh/neovim-csharp.zsh")), "templates/neovim-csharp.zsh"),
    M.file_check("Ghostty config", read_lines(config_path("templates/ghostty-config")),
      read_lines(home(".config/ghostty/config")), "templates/ghostty-config"),
    M.symlink_check("~/.claude/CLAUDE.md link", home(".claude/CLAUDE.md"),
      config_path("templates/claude-global.md"), "templates/claude-global.md"),
  }

  local zshrc = read_lines(home(".zshrc")) or {}
  local sourced = false
  for _, line in ipairs(zshrc) do
    if line:find("config/zsh/neovim-csharp.zsh", 1, true) and not line:match("^%s*#") then sourced = true end
  end
  results[#results + 1] = check("Deployed files", sourced and "ok" or "fail", "~/.zshrc sources the zsh config",
    sourced and "yes" or "no source line found")

  local suggestions = home(".config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh")
  local present = vim.uv.fs_stat(suggestions) ~= nil
  results[#results + 1] = check("Deployed files", present and "ok" or "fail", "zsh-autosuggestions", present and "installed" or "missing: " .. suggestions)
  return results
end

-- ----------------------------------------------------------------------- Ghostty
local function ghostty_binary()
  local path = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
  return vim.fn.executable(path) == 1 and path or nil
end

local function ghostty_checks()
  local section = "Ghostty"
  local binary = ghostty_binary()
  if not binary then return { check(section, "warn", "Ghostty applied settings", "Ghostty not found in /Applications") } end

  local results = {}
  local library = home("Library/Application Support/com.mitchellh.ghostty/config")
  if vim.uv.fs_stat(library) then
    results[#results + 1] = check(section, "warn", "Second Ghostty config", library .. " exists and is read after ~/.config/ghostty/config, so it can override it")
  else
    results[#results + 1] = check(section, "ok", "Second Ghostty config", "none in ~/Library/Application Support")
  end

  local template = read_lines(config_path("templates/ghostty-config"))
  local effective = run({ binary, "+show-config" })
  local defaults = run({ binary, "+show-config", "--default" })
  if not template or not effective then
    results[#results + 1] = check(section, "warn", "Ghostty applied settings", "could not read the template or ghostty +show-config")
    return results
  end
  local missing = M.ghostty_mismatches(template, effective, defaults)
  if #missing == 0 then
    results[#results + 1] = check(section, "ok", "Ghostty applied settings", "every setting and keybind of templates/ghostty-config is in effect")
  else
    results[#results + 1] = check(section, "warn", "Ghostty applied settings", "not in effect: " .. table.concat(missing, "; "))
  end
  return results
end

-- ------------------------------------------------------------------ environment
local function environment_checks()
  local section = "Environment"
  local version = vim.version()
  local uname = vim.uv.os_uname()
  local macos = first_line(run({ "sw_vers", "-productVersion" }))
  local ghostty = ghostty_binary() and first_line(run({ ghostty_binary(), "--version" })) or nil
  return {
    check(section, "ok", "Neovim", string.format("%d.%d.%d (%s, %s)", version.major, version.minor, version.patch, vim.v.progpath, uname.machine)),
    check(section, "ok", "macOS", macos or uname.sysname .. " " .. uname.release),
    check(section, "ok", "Shell", vim.env.SHELL or "unknown"),
    check(section, ghostty and "ok" or "warn", "Terminal", (vim.env.TERM_PROGRAM or "unknown") .. (ghostty and ", " .. ghostty or " (Ghostty not found)")),
  }
end

-- ------------------------------------------------------------------------ tools
-- level: "required" (the config breaks without it), "optional" (a feature is lost), "elm" (only for Elm).
local TOOLS = {
  { "dotnet", "required", { "--version" } },
  { "git", "required", { "--version" } },
  { "rg", "required", { "--version" } },
  { "fd", "required", { "--version" } },
  { "tree-sitter", "required", { "--version" } },
  { "jq", "optional", { "--version" } },
  { "fzf", "optional", { "--version" } },
  { "zoxide", "optional", { "--version" } },
  { "bat", "optional", { "--version" } },
  { "terminal-notifier", "optional" },
  { "node", "elm", { "--version" } },
  { "elm", "elm", { "--version" } },
  { "elm-format", "elm" },
  { "elm-language-server", "elm" },
  { "elm-test", "elm" },
  { "fossil", "elm", { "version" } },
}

local function tool_checks()
  local results = {}
  local script = read_lines(config_path("bootstrap-macos.sh"))
  local pinned = script and M.pinned_roslyn("\n" .. table.concat(script, "\n")) or nil
  local listing = vim.fn.executable("dotnet") == 1 and run({ "dotnet", "tool", "list", "-g" }) or nil
  results[#results + 1] = M.roslyn_check(pinned, listing and M.installed_roslyn(listing) or nil)

  for _, tool in ipairs(TOOLS) do
    local name, level, version_args = tool[1], tool[2], tool[3]
    local path = vim.fn.exepath(name)
    if path ~= "" then
      local version = version_args and first_line(run(vim.list_extend({ path }, version_args))) or nil
      results[#results + 1] = check("Tools", "ok", name, path .. (version and "  (" .. shorten(version, 40) .. ")" or ""))
    else
      -- Elm tooling is skipped on purpose by `bootstrap-macos.sh --no-elm`, so it is information, not a problem.
      local status = level == "required" and "fail" or level == "optional" and "warn" or "info"
      local detail = level == "required" and "not found" or level == "optional" and "not found (optional)" or "not installed (only needed for Elm)"
      results[#results + 1] = check("Tools", status, name, detail)
    end
  end
  return results
end

-- ------------------------------------------------------------ parsers, debugger
local function parser_checks()
  local results = {}
  local parser_dir = vim.fn.stdpath("data") .. "/site/parser/"
  local languages = { "c_sharp", "mssql", "json" }
  if vim.fn.executable("elm") == 1 then languages[#languages + 1] = "elm" end
  for _, language in ipairs(languages) do
    local present = vim.uv.fs_stat(parser_dir .. language .. ".so") ~= nil
    results[#results + 1] = check("Parsers and debugger", present and "ok" or "fail", "Tree-sitter parser: " .. language, present and "installed" or "missing")
  end
  local debugger = vim.fn.stdpath("data") .. "/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
  local present = vim.fn.executable(debugger) == 1
  results[#results + 1] = check("Parsers and debugger", present and "ok" or "fail", "netcoredbg debugger", present and debugger or "not found: " .. debugger)
  return results
end

-- Starts every process the checks will ask for, so they run concurrently.
local function prefetch()
  start({ "sw_vers", "-productVersion" })
  local ghostty = ghostty_binary()
  if ghostty then
    start({ ghostty, "--version" })
    start({ ghostty, "+show-config" })
    start({ ghostty, "+show-config", "--default" })
  end
  if vim.fn.executable("dotnet") == 1 then start({ "dotnet", "tool", "list", "-g" }) end
  for _, tool in ipairs(TOOLS) do
    local path = vim.fn.exepath(tool[1])
    if path ~= "" and tool[3] then start(vim.list_extend({ path }, tool[3])) end
  end
  local lock = read_lock()
  if lock then
    for name in pairs(lock) do start(head_command(name)) end
  end
end

-- Collects every check. It is an on-demand report, not something on the startup path, so it waits for
-- the (concurrently started) processes instead of going asynchronous.
function M.collect(verbose)
  jobs = {}
  prefetch()
  local results = {}
  vim.list_extend(results, environment_checks())
  vim.list_extend(results, deployed_file_checks())
  vim.list_extend(results, ghostty_checks())
  vim.list_extend(results, tool_checks())
  vim.list_extend(results, plugin_checks(verbose))
  vim.list_extend(results, parser_checks())
  return results
end

function M.render(results)
  local width = 0
  for _, item in ipairs(results) do width = math.max(width, #item.label) end
  local counts = { ok = 0, warn = 0, fail = 0, info = 0 }
  local lines = { "NeoDoctor" }
  local section
  for _, item in ipairs(results) do
    if item.section ~= section then
      section = item.section
      lines[#lines + 1] = ""
      if section then lines[#lines + 1] = section end
    end
    counts[item.status] = counts[item.status] + 1
    lines[#lines + 1] = string.format("[%-4s] %-" .. width .. "s  %s", STATUS[item.status], item.label, item.detail)
  end
  lines[#lines + 1] = ""
  local summary = string.format("%d ok, %d warnings, %d failures", counts.ok, counts.warn, counts.fail)
  if counts.info > 0 then summary = summary .. string.format(", %d not installed (info)", counts.info) end
  lines[#lines + 1] = summary .. "    (q closes this window; :NeoDoctor! lists every plugin)"
  return lines
end

function M.report(verbose)
  return M.render(M.collect(verbose))
end

function M.open(verbose)
  local lines = M.report(verbose)
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
  vim.api.nvim_create_user_command("NeoDoctor", function(command) M.open(command.bang) end, {
    bang = true,
    desc = "Check this machine against the config's expectations (! lists every plugin)",
  })
end

return M
