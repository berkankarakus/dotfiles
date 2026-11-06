local M = {}
local namespace_cache = {}
local SKIP_NAMESPACE_DIRS = { [".git"] = true, [".vs"] = true, bin = true, obj = true, node_modules = true }

local function namespace_from_source(source_file)
  for _, line in ipairs(vim.fn.readfile(source_file)) do
    local namespace = line:match("^%s*namespace%s+([%w_.]+)%s*[;{]")
    if namespace then return namespace end
  end
end

local function find_namespace(directory)
  local entries = {}
  for name, kind in vim.fs.dir(directory) do
    if kind == "file" and name:sub(-3) == ".cs" then
      entries[#entries + 1] = { name = name, kind = kind }
    elseif kind == "directory" and not SKIP_NAMESPACE_DIRS[name] then
      entries[#entries + 1] = { name = name, kind = kind }
    end
  end
  table.sort(entries, function(left, right) return left.name < right.name end)

  for _, entry in ipairs(entries) do
    local path = vim.fs.joinpath(directory, entry.name)
    if entry.kind == "file" then
      local namespace = namespace_from_source(path)
      if namespace then return namespace, path end
    else
      local namespace, source_file = find_namespace(path)
      if namespace then return namespace, source_file end
    end
  end
end

local function namespace_root_from_project(project_file)
  project_file = vim.fs.normalize(project_file)
  if namespace_cache[project_file] then return namespace_cache[project_file] end
  local project_dir = vim.fs.dirname(project_file)
  for _, line in ipairs(vim.fn.readfile(project_file)) do
    local root_namespace = line:match("<RootNamespace>([%w_.]+)</RootNamespace>")
    if root_namespace then
      namespace_cache[project_file] = root_namespace
      return root_namespace
    end
  end

  local namespace, source_file = find_namespace(project_dir)
  if namespace then
    local relative_dir = vim.fs.relpath(project_dir, vim.fs.dirname(source_file))
    if relative_dir and relative_dir ~= "." then
      local suffix = "." .. relative_dir:gsub("[/\\]", ".")
      if namespace:sub(-#suffix) == suffix then namespace = namespace:sub(1, #namespace - #suffix) end
    end
    namespace_cache[project_file] = namespace
    return namespace
  end
  local fallback = vim.fn.fnamemodify(project_file, ":t:r")
  namespace_cache[project_file] = fallback
  return fallback
end

local function create(event)
  local buf = event.buf
  local filename = vim.api.nvim_buf_get_name(buf)
  -- BufReadPost is included so `touch NewClass.cs` works too; only empty
  -- files receive a namespace, summary, and type skeleton.
  if event.event == "BufReadPost" and vim.fn.getfsize(filename) ~= 0 then return end
  if vim.b[buf].neo_csharp_skeleton_pending then return end
  vim.b[buf].neo_csharp_skeleton_pending = true

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.b[buf].neo_csharp_skeleton_pending = nil
    if vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= "" then return end

    local file_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
    local project_file = vim.fs.find(function(name) return name:sub(-7) == ".csproj" end, {
      path = file_dir,
      upward = true,
      limit = 1,
    })[1]
    if not project_file then return end

    local project_dir = vim.fs.dirname(project_file)
    local relative_dir = vim.fs.relpath(project_dir, file_dir)
    local namespace = namespace_root_from_project(project_file)
    if relative_dir and relative_dir ~= "." then
      namespace = namespace .. "." .. relative_dir:gsub("[/\\]", "."):gsub("[^%w_.]", "_")
    end
    local filename = vim.api.nvim_buf_get_name(buf)
    local class_name = vim.fn.fnamemodify(filename, ":t:r"):gsub("[^%w_]", "_")
    if class_name:match("^%d") then class_name = "_" .. class_name end
    local declaration = class_name:match("^I[A-Z]")
        and "public interface " .. class_name
      or "public class " .. class_name .. "()"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "namespace " .. namespace .. ";",
      "",
      "/// <summary>",
      "/// ",
      "/// </summary>",
      declaration,
      "{",
      "    ",
      "}",
    })

    local win = vim.fn.bufwinid(buf)
    if win == -1 then return end
    vim.api.nvim_win_set_cursor(win, { 4, 4 })
    if vim.api.nvim_get_current_win() ~= win then return end
    vim.cmd("startinsert")
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_win() == win then
        vim.api.nvim_feedkeys(vim.keycode("<Right>"), "n", false)
      end
    end)
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CSharpFileSkeleton", { clear = true })
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
    group = group,
    pattern = "*.cs",
    callback = create,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.csproj",
    callback = function(event) namespace_cache[vim.fs.normalize(vim.api.nvim_buf_get_name(event.buf))] = nil end,
  })
end

return M
