local M = {}

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

local function read_lock(ctx)
  local lines = ctx.read_lines(ctx.config_path("lazy-lock.json"))
  if not lines then return nil, "lazy-lock.json not found" end
  local decode_ok, lock = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok then return nil, "lazy-lock.json is not valid JSON" end
  return lock
end

local function head_command(name)
  return { "git", "-C", require("lazy.core.config").options.root .. "/" .. name, "rev-parse", "HEAD" }
end

local function environment(ctx)
  local section = "Environment"
  local version = vim.version()
  local uname = vim.uv.os_uname()
  local macos = ctx.first_line(ctx.run({ "sw_vers", "-productVersion" }))
  local ghostty = ctx.ghostty_binary() and ctx.first_line(ctx.run({ ctx.ghostty_binary(), "--version" })) or nil
  return {
    ctx.check(section, "ok", "Neovim", string.format("%d.%d.%d (%s, %s)", version.major, version.minor, version.patch, vim.v.progpath, uname.machine)),
    ctx.check(section, "ok", "macOS", macos or uname.sysname .. " " .. uname.release),
    ctx.check(section, "ok", "Shell", vim.env.SHELL or "unknown"),
    ctx.check(section, ghostty and "ok" or "warn", "Terminal", (vim.env.TERM_PROGRAM or "unknown") .. (ghostty and ", " .. ghostty or " (Ghostty not found)")),
  }
end

local function deployed_files(ctx)
  local results = {
    ctx.checks.file_check("zsh config", ctx.read_lines(ctx.config_path("templates/neovim-csharp.zsh")),
      ctx.read_lines(ctx.home(".config/zsh/neovim-csharp.zsh")), "templates/neovim-csharp.zsh"),
    ctx.checks.file_check("Ghostty config", ctx.read_lines(ctx.config_path("templates/ghostty-config")),
      ctx.read_lines(ctx.home(".config/ghostty/config")), "templates/ghostty-config"),
    ctx.checks.symlink_check("~/.claude/CLAUDE.md link", ctx.home(".claude/CLAUDE.md"),
      ctx.config_path("templates/claude-global.md"), "templates/claude-global.md"),
  }

  if vim.uv.fs_stat(ctx.home(".codex")) then
    results[#results + 1] = ctx.checks.symlink_check("~/.codex/AGENTS.md link", ctx.home(".codex/AGENTS.md"),
      ctx.config_path("templates/codex-global.md"), "templates/codex-global.md")
  end

  local zshrc = ctx.read_lines(ctx.home(".zshrc")) or {}
  local sourced = false
  for _, line in ipairs(zshrc) do
    if line:find("config/zsh/neovim-csharp.zsh", 1, true) and not line:match("^%s*#") then sourced = true end
  end
  results[#results + 1] = ctx.check("Deployed files", sourced and "ok" or "fail", "~/.zshrc sources the zsh config",
    sourced and "yes" or "no source line found")

  local suggestions = ctx.home(".config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh")
  local present = vim.uv.fs_stat(suggestions) ~= nil
  results[#results + 1] = ctx.check("Deployed files", present and "ok" or "fail", "zsh-autosuggestions", present and "installed" or "missing: " .. suggestions)
  return results
end

local function ghostty(ctx)
  local section = "Ghostty"
  local binary = ctx.ghostty_binary()
  if not binary then return { ctx.check(section, "warn", "Ghostty applied settings", "Ghostty not found in /Applications") } end

  local results = {}
  local library = ctx.home("Library/Application Support/com.mitchellh.ghostty/config")
  results[#results + 1] = ctx.check(section, vim.uv.fs_stat(library) and "warn" or "ok", "Second Ghostty config",
    vim.uv.fs_stat(library) and library .. " exists and is read after ~/.config/ghostty/config, so it can override it"
      or "none in ~/Library/Application Support")

  local template = ctx.read_lines(ctx.config_path("templates/ghostty-config"))
  local effective = ctx.run({ binary, "+show-config" })
  local defaults = ctx.run({ binary, "+show-config", "--default" })
  if not template or not effective then
    results[#results + 1] = ctx.check(section, "warn", "Ghostty applied settings", "could not read the template or ghostty +show-config")
    return results
  end
  local missing = ctx.checks.ghostty_mismatches(template, effective, defaults)
  results[#results + 1] = ctx.check(section, #missing == 0 and "ok" or "warn", "Ghostty applied settings",
    #missing == 0 and "every setting and keybind of templates/ghostty-config is in effect"
      or "not in effect: " .. table.concat(missing, "; "))
  return results
end

local function plugins(ctx, verbose)
  local lock, problem = read_lock(ctx)
  if not lock then return { ctx.check("Plugins", "warn", "Plugins match lazy-lock.json", problem) } end
  local heads = {}
  for name in pairs(lock) do heads[name] = ctx.run(head_command(name)) end
  return ctx.checks.lock_checks(lock, heads, verbose)
end

local function tools(ctx)
  local results = {}
  local script = ctx.read_lines(ctx.config_path("bootstrap-macos.sh"))
  local pinned = script and ctx.checks.pinned_roslyn("\n" .. table.concat(script, "\n")) or nil
  local listing = vim.fn.executable("dotnet") == 1 and ctx.run({ "dotnet", "tool", "list", "-g" }) or nil
  results[#results + 1] = ctx.checks.roslyn_check(pinned, listing and ctx.checks.installed_roslyn(listing) or nil)

  for _, tool in ipairs(TOOLS) do
    local name, level, version_args = tool[1], tool[2], tool[3]
    local path = vim.fn.exepath(name)
    if path ~= "" then
      local version = version_args and ctx.first_line(ctx.run(vim.list_extend({ path }, version_args))) or nil
      results[#results + 1] = ctx.check("Tools", "ok", name, path .. (version and "  (" .. ctx.checks.shorten(version, 40) .. ")" or ""))
    else
      local status = level == "required" and "fail" or level == "optional" and "warn" or "info"
      local detail = level == "required" and "not found" or level == "optional" and "not found (optional)" or "not installed (only needed for Elm)"
      results[#results + 1] = ctx.check("Tools", status, name, detail)
    end
  end
  return results
end

local function parsers(ctx)
  local results = {}
  local parser_dir = vim.fn.stdpath("data") .. "/site/parser/"
  local languages = { "c_sharp", "mssql", "json" }
  if vim.fn.executable("elm") == 1 then languages[#languages + 1] = "elm" end
  for _, language in ipairs(languages) do
    local present = vim.uv.fs_stat(parser_dir .. language .. ".so") ~= nil
    results[#results + 1] = ctx.check("Parsers and debugger", present and "ok" or "fail", "Tree-sitter parser: " .. language, present and "installed" or "missing")
  end
  local debugger = vim.fn.stdpath("data") .. "/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
  local present = vim.fn.executable(debugger) == 1
  results[#results + 1] = ctx.check("Parsers and debugger", present and "ok" or "fail", "netcoredbg debugger", present and debugger or "not found: " .. debugger)
  return results
end

function M.prefetch(ctx)
  ctx.start({ "sw_vers", "-productVersion" })
  local ghostty = ctx.ghostty_binary()
  if ghostty then
    ctx.start({ ghostty, "--version" })
    ctx.start({ ghostty, "+show-config" })
    ctx.start({ ghostty, "+show-config", "--default" })
  end
  if vim.fn.executable("dotnet") == 1 then ctx.start({ "dotnet", "tool", "list", "-g" }) end
  for _, tool in ipairs(TOOLS) do
    local path = vim.fn.exepath(tool[1])
    if path ~= "" and tool[3] then ctx.start(vim.list_extend({ path }, tool[3])) end
  end
  local lock = read_lock(ctx)
  if lock then
    for name in pairs(lock) do ctx.start(head_command(name)) end
  end
end

function M.collect(ctx, verbose)
  M.prefetch(ctx)
  local results = {}
  vim.list_extend(results, environment(ctx))
  vim.list_extend(results, deployed_files(ctx))
  vim.list_extend(results, ghostty(ctx))
  vim.list_extend(results, tools(ctx))
  vim.list_extend(results, plugins(ctx, verbose))
  vim.list_extend(results, parsers(ctx))
  return results
end

return M
