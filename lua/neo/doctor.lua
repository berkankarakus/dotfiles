-- :NeoDoctor lists everything this config depends on and whether this machine matches it, so two
-- machines can be compared line by line. Collection details live in neo.doctor.collectors; this
-- module owns the process cache, report rendering, and user command.
local M = {}
local checks = require("neo.doctor.checks")
local collectors = require("neo.doctor.collectors")

local STATUS = { ok = "ok", warn = "WARN", fail = "FAIL", info = "info" }
local jobs = {}

local function check(section, status, label, detail)
  return { section = section, status = status, label = label, detail = detail }
end

local function config_path(relative) return vim.fn.stdpath("config") .. "/" .. relative end
local function home(relative) return vim.fn.expand("~") .. "/" .. relative end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or nil
end

local function job_key(command) return table.concat(command, "\0") end

local function start(command)
  local key = job_key(command)
  if jobs[key] ~= nil then return end
  local ok, process = pcall(vim.system, command, { text = true })
  jobs[key] = ok and { process = process } or { failed = true }
end

local function run(command)
  start(command)
  local job = jobs[job_key(command)]
  if job.failed then return nil end
  if not job.result then job.result = job.process:wait(8000) end
  if job.result.code ~= 0 then return nil end
  return vim.trim((job.result.stdout or "") .. (job.result.stderr or ""))
end

local function first_line(text) return text and text:match("[^\n]+") or nil end

local function ghostty_binary()
  local path = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
  return vim.fn.executable(path) == 1 and path or nil
end

M.pinned_roslyn = checks.pinned_roslyn
M.installed_roslyn = checks.installed_roslyn
M.roslyn_check = checks.roslyn_check
M.lock_checks = checks.lock_checks
M.first_difference = checks.first_difference
M.file_check = checks.file_check
M.symlink_check = checks.symlink_check
M.ghostty_mismatches = checks.ghostty_mismatches

function M.collect(verbose)
  jobs = {}
  local context = {
    check = check,
    config_path = config_path,
    home = home,
    read_lines = read_lines,
    start = start,
    run = run,
    first_line = first_line,
    ghostty_binary = ghostty_binary,
    checks = checks,
  }
  return collectors.collect(context, verbose)
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
