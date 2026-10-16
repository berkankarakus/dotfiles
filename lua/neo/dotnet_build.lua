-- `dotnet build` as an editor action: errors and warnings from every file of the solution land in
-- the quickfix list, so they can be walked with :cnext even for files that are not open (Roslyn
-- only reports diagnostics for open buffers).
local M = {}

-- Same pattern as Neovim's runtime `compiler dotnet` (dotnet_show_project_file = false):
-- "path(line,col): error CS1002: message [project]".
M.errorformat = "%E%f(%l\\,%c): %trror %m [%.%#],%W%f(%l\\,%c): %tarning %m [%.%#],%-G%.%#"

local building = false
-- After a failed build the quickfix window holds focus and has no file of its own, so the next
-- build (the one after fixing the errors) falls back to the target that was built last.
M.last_target = nil

local function find_upward(start_dir, matches)
  return vim.fs.find(matches, { path = start_dir, upward = true, limit = 1 })[1]
end

-- The solution wins over a project so one build covers everything; the project is the fallback.
function M.find_target(start_dir)
  return find_upward(start_dir, function(name) return name:match("%.slnx?$") ~= nil end)
    or find_upward(start_dir, function(name) return name:sub(-7) == ".csproj" end)
end

local function start_dir()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  -- oil:// and terminal buffers have no real directory of their own.
  if buffer_name == "" or buffer_name:match("^%a[%w+.-]*://") then return vim.fn.getcwd() end
  return vim.fs.dirname(buffer_name)
end

-- MSBuild prints every diagnostic twice (once while building, once in the summary), so duplicates
-- are dropped. Returns quickfix items plus the error and warning counts.
function M.parse(lines)
  local parsed = vim.fn.getqflist({ lines = lines, efm = M.errorformat }).items
  local items, seen = {}, {}
  local errors, warnings = 0, 0
  for _, item in ipairs(parsed) do
    if item.valid == 1 then
      local key = table.concat({ item.bufnr, item.lnum, item.col, item.type, item.text }, "\0")
      if not seen[key] then
        seen[key] = true
        items[#items + 1] = item
        -- %t yields the letter as written ("e"/"w") depending on the pattern, so compare case-insensitively.
        if item.type:upper() == "E" then errors = errors + 1 else warnings = warnings + 1 end
      end
    end
  end
  return items, errors, warnings
end

-- Replaced in tests. Calls on_exit({ code, stdout, stderr }) on the main loop.
function M.run(command, cwd, on_exit)
  vim.system(command, {
    cwd = cwd,
    text = true,
    env = { DOTNET_NOLOGO = "1", DOTNET_CLI_TELEMETRY_OPTOUT = "1" },
  }, vim.schedule_wrap(on_exit))
end

local function plural(count, noun) return string.format("%d %s%s", count, noun, count == 1 and "" or "s") end

local function finish(result, name, on_done)
  building = false
  local lines = vim.split((result.stdout or "") .. (result.stderr or ""), "\n", { trimempty = true })
  local items, errors, warnings = M.parse(lines)
  vim.fn.setqflist({}, " ", { title = "dotnet build " .. name, items = items })

  if errors > 0 then
    vim.cmd("botright copen")
    vim.notify(string.format("Build failed: %s, %s.", plural(errors, "error"), plural(warnings, "warning")), vim.log.levels.ERROR)
  elseif result.code ~= 0 then
    -- Nothing with a file position (missing project, restore failure, ...): show the tail instead.
    local tail = vim.list_slice(lines, math.max(1, #lines - 9))
    vim.notify("Build failed:\n" .. table.concat(tail, "\n"), vim.log.levels.ERROR)
  elseif warnings > 0 then
    vim.cmd("cclose")
    vim.notify(string.format("Build succeeded with %s (see :copen).", plural(warnings, "warning")), vim.log.levels.WARN)
  else
    vim.cmd("cclose")
    vim.notify("Build succeeded.", vim.log.levels.INFO)
  end
  if on_done then on_done({ code = result.code, errors = errors, warnings = warnings }) end
end

-- Builds the solution (or project) above the current file without blocking the editor.
function M.build(on_done)
  if building then
    vim.notify("dotnet build is already running.", vim.log.levels.INFO)
    return
  end
  local target = M.find_target(start_dir()) or M.find_target(vim.fn.getcwd()) or M.last_target
  if not target then
    vim.notify("No .sln, .slnx or .csproj found above this file.", vim.log.levels.WARN)
    return
  end

  building = true
  M.last_target = target
  local name = vim.fs.basename(target)
  vim.notify("Building " .. name .. "...", vim.log.levels.INFO)
  M.run({ "dotnet", "build", target, "--nologo", "-v", "q", "-clp:NoSummary" }, vim.fs.dirname(target), function(result)
    finish(result, name, on_done)
  end)
end

function M.setup()
  vim.keymap.set("n", "<leader>rb", function() M.build() end, { desc = "Build solution (errors to quickfix)" })
  vim.api.nvim_create_user_command("DotnetBuild", function() M.build() end, { desc = "dotnet build with errors in quickfix" })
end

return M
