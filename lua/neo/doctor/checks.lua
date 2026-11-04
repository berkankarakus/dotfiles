local M = {}

local function check(section, status, label, detail)
  return { section = section, status = status, label = label, detail = detail }
end

function M.pinned_roslyn(script_text)
  return script_text:match('\nROSLYN_VERSION="([^"]+)"') or script_text:match('^ROSLYN_VERSION="([^"]+)"')
end

function M.installed_roslyn(tool_list)
  for line in tool_list:gmatch("[^\n]+") do
    local name, version = line:match("^(%S+)%s+(%S+)")
    if name == "roslyn-language-server" then return version end
  end
end

function M.roslyn_check(pinned, installed)
  local section = "Tools"
  if not installed then return check(section, "fail", "Roslyn language server", "not installed (dotnet tool install -g roslyn-language-server)") end
  if not pinned then return check(section, "warn", "Roslyn language server", installed .. " (pinned version unknown: bootstrap-macos.sh not found)") end
  if installed ~= pinned then
    return check(section, "warn", "Roslyn language server", string.format("installed %s, pinned %s", installed, pinned))
  end
  return check(section, "ok", "Roslyn language server", installed)
end

-- `lock` is the decoded lazy-lock.json, `heads` maps plugin name -> installed commit (nil if missing).
function M.lock_checks(lock, heads, verbose)
  local section = "Plugins"
  local names = vim.tbl_keys(lock)
  table.sort(names)
  local missing, drifted, listing = {}, {}, {}
  for _, name in ipairs(names) do
    local wanted, actual = lock[name].commit, heads[name]
    if not actual then
      missing[#missing + 1] = name
      listing[#listing + 1] = check(section, "fail", name, "not installed (lock " .. wanted:sub(1, 7) .. ")")
    elseif actual ~= wanted then
      drifted[#drifted + 1] = string.format("%s (installed %s, lock %s)", name, actual:sub(1, 7), wanted:sub(1, 7))
      listing[#listing + 1] = check(section, "warn", name, string.format("installed %s, lock %s", actual:sub(1, 7), wanted:sub(1, 7)))
    else
      listing[#listing + 1] = check(section, "ok", name, actual:sub(1, 7))
    end
  end
  if verbose then return listing end

  local results = {}
  if #missing > 0 then results[#results + 1] = check(section, "fail", "Plugins installed", "missing: " .. table.concat(missing, ", ")) end
  if #drifted > 0 then results[#results + 1] = check(section, "warn", "Plugins match lazy-lock.json", table.concat(drifted, "; ")) end
  if #missing == 0 and #drifted == 0 then
    results[#results + 1] = check(section, "ok", "Plugins match lazy-lock.json", #names .. " plugins at their locked commits")
  end
  return results
end

function M.first_difference(left, right)
  for index = 1, math.max(#left, #right) do
    if left[index] ~= right[index] then return { line = index, left = left[index], right = right[index] } end
  end
end

local function shorten(text, width)
  if not text then return "(end of file)" end
  text = vim.trim(text)
  return #text > width and text:sub(1, width - 1) .. "…" or text
end
M.shorten = shorten

function M.file_check(label, template_lines, deployed_lines, template_name)
  local section = "Deployed files"
  if not deployed_lines then return check(section, "fail", label, "not deployed (run bootstrap-macos.sh)") end
  if not template_lines then return check(section, "warn", label, template_name .. " not found in the repo") end
  local difference = M.first_difference(template_lines, deployed_lines)
  if not difference then return check(section, "ok", label, "matches " .. template_name) end
  return check(section, "warn", label, string.format('differs from %s at line %d: deployed "%s", template "%s"',
    template_name, difference.line, shorten(difference.right, 50), shorten(difference.left, 50)))
end

function M.symlink_check(label, link_path, target_path, target_name)
  local section = "Deployed files"
  local info = vim.uv.fs_lstat(link_path)
  if not info then return check(section, "warn", label, "missing (see README, Yeni Mac'e Taşıma)") end
  if info.type ~= "link" then
    return check(section, "warn", label, "an ordinary file, no longer linked to " .. target_name)
  end
  local actual = vim.uv.fs_realpath(link_path)
  local expected = vim.uv.fs_realpath(target_path)
  if not actual then return check(section, "warn", label, "a broken link to " .. (vim.uv.fs_readlink(link_path) or "?")) end
  if actual ~= expected then return check(section, "warn", label, "links to " .. actual .. ", not " .. target_name) end
  return check(section, "ok", label, "links to " .. target_name)
end

local function normalize_ghostty(line)
  return (line:gsub("\\", ""):gsub("option%+", "alt+"):gsub("command%+", "super+"))
end

function M.ghostty_mismatches(template_lines, effective_text, default_text)
  local effective, overridden, defaults = {}, {}, {}
  for line in effective_text:gmatch("[^\n]+") do
    local normalized = normalize_ghostty(vim.trim(line))
    effective[normalized] = true
    local key = normalized:match("^([%w-]+) =")
    if key then overridden[key] = true end
  end
  for line in (default_text or ""):gmatch("[^\n]+") do defaults[normalize_ghostty(vim.trim(line))] = true end

  local missing = {}
  for _, line in ipairs(template_lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      local normalized = normalize_ghostty(trimmed)
      local key = normalized:match("^([%w-]+) =")
      local at_default = key and key ~= "keybind" and not overridden[key] and defaults[normalized]
      if not effective[normalized] and not at_default then missing[#missing + 1] = trimmed end
    end
  end
  return missing
end

return M
