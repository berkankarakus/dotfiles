local M = {}

local function dotnet_project_file()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  local start_path = buffer_name ~= "" and vim.fs.dirname(buffer_name) or vim.fn.getcwd()
  return vim.fs.find(function(name) return name:sub(-7) == ".csproj" end, {
    path = start_path,
    upward = true,
    limit = 1,
  })[1]
end
local function project_sdk(project_file)
  if not project_file or vim.fn.filereadable(project_file) == 0 then return false end
  local project_text = table.concat(vim.fn.readfile(project_file), "\n")
  return project_text:match('<Project[^>]-Sdk%s*=%s*["\']([^"\']+)["\']')
end
local function project_is_executable(project_file)
  if not project_file or vim.fn.filereadable(project_file) == 0 then return false end
  local project_text = table.concat(vim.fn.readfile(project_file), "\n")
  local has_executable_output = project_text:match("<OutputType>%s*[Ww]?Exe%s*</OutputType>") ~= nil
  local sdk = project_sdk(project_file)
  return has_executable_output or sdk == "Microsoft.NET.Sdk.Web" or sdk == "Microsoft.NET.Sdk.Worker"
end
local function debug_project_file()
  local nearest_project = dotnet_project_file()
  if project_is_executable(nearest_project) then return nearest_project end

  local start_path = nearest_project and vim.fs.dirname(nearest_project) or vim.fn.getcwd()
  local solution_file = vim.fs.find(function(name) return name:match("%.slnx?$") ~= nil end, {
    path = start_path,
    upward = true,
    limit = 1,
  })[1]
  if not solution_file then return nearest_project end

  local executable_projects = {}
  for _, project_file in ipairs(vim.fn.globpath(vim.fs.dirname(solution_file), "**/*.csproj", false, true)) do
    if project_is_executable(project_file) then table.insert(executable_projects, project_file) end
  end
  if #executable_projects == 1 then return executable_projects[1] end
  if #executable_projects > 1 then
    local choices = { "Select executable project:" }
    for index, project_file in ipairs(executable_projects) do
      choices[index + 1] = vim.fn.fnamemodify(project_file, ":.")
    end
    local selection = vim.fn.inputlist(choices)
    return executable_projects[selection]
  end
  return nearest_project
end
local function dotnet_program(project_file)
  if project_file then
    local project_dir = vim.fs.dirname(project_file)
    local project_name = vim.fn.fnamemodify(project_file, ":t:r")
    for _, dll in ipairs(vim.fn.globpath(project_dir, "bin/Debug/**/*.dll", false, true)) do
      local runtime_config = dll:gsub("%.dll$", ".runtimeconfig.json")
      if vim.fn.fnamemodify(dll, ":t") == project_name .. ".dll" and vim.fn.filereadable(runtime_config) == 1 then
        return dll
      end
    end
    return vim.fn.input("Path to DLL: ", project_dir .. "/bin/Debug/", "file")
  end
  return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
end
local function dotnet_launch_profile(project_file)
  if not project_file then return { cwd = vim.fn.getcwd(), args = {}, env = {} } end

  local project_dir = vim.fs.dirname(project_file)
  local launch_settings = project_dir .. "/Properties/launchSettings.json"
  if vim.fn.filereadable(launch_settings) == 0 then
    return { cwd = project_dir, args = {}, env = {} }
  end

  local ok, settings = pcall(vim.json.decode, table.concat(vim.fn.readfile(launch_settings), "\n"))
  if not ok then
    vim.notify("Could not read launchSettings.json", vim.log.levels.WARN)
    return { cwd = project_dir, args = {}, env = {} }
  end

  for _, profile in pairs(settings.profiles or {}) do
    if profile.commandName == "Project" then
      local args = profile.commandLineArgs and require("dap.utils").splitstr(profile.commandLineArgs) or {}
      local env = vim.deepcopy(profile.environmentVariables or {})
      if profile.applicationUrl and not env.ASPNETCORE_URLS then
        env.ASPNETCORE_URLS = profile.applicationUrl
      end

      local browser_url
      if project_sdk(project_file) == "Microsoft.NET.Sdk.Web" and profile.launchBrowser and profile.applicationUrl then
        local base_url = vim.split(profile.applicationUrl, ";", { plain = true })[1]
        local launch_path = profile.launchUrl or ""
        browser_url = base_url:gsub("/$", "")
        if launch_path ~= "" then browser_url = browser_url .. "/" .. launch_path:gsub("^/", "") end
      end
      return { cwd = project_dir, args = args, env = env, browser_url = browser_url }
    end
  end
  return { cwd = project_dir, args = {}, env = {}, browser_url = nil }
end

function M.launch_context_cache(resolve)
  local resolved = false
  local value

  return {
    get = function()
      if not resolved then
        value = resolve()
        resolved = true
      end
      return value
    end,
    reset = function()
      resolved = false
      value = nil
    end,
  }
end

-- Project discovery for the debugger. `debug_project_file` may prompt (vim.fn.inputlist) when a
-- solution holds several executable projects, and `program` may prompt for a DLL path.
M.project_file = dotnet_project_file
M.project_sdk = project_sdk
M.project_is_executable = project_is_executable
M.debug_project_file = debug_project_file
M.program = dotnet_program
M.launch_profile = dotnet_launch_profile

function M.resolve_launch_context()
  local project_file = debug_project_file()
  return {
    program = dotnet_program(project_file),
    profile = dotnet_launch_profile(project_file),
  }
end

return M
