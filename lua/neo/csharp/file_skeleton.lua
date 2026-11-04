local M = {}
local namespace_cache = {}

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

  for _, source_file in ipairs(vim.fn.globpath(project_dir, "**/*.cs", false, true)) do
    if not source_file:find("/bin/") and not source_file:find("/obj/") then
      for _, line in ipairs(vim.fn.readfile(source_file)) do
        local namespace = line:match("^%s*namespace%s+([%w_.]+)%s*[;{]")
        if namespace then
          local relative_dir = vim.fs.relpath(project_dir, vim.fs.dirname(source_file))
          if relative_dir and relative_dir ~= "." then
            local suffix = "." .. relative_dir:gsub("[/\\]", ".")
            if namespace:sub(-#suffix) == suffix then
              namespace = namespace:sub(1, #namespace - #suffix)
              namespace_cache[project_file] = namespace
              return namespace
            end
          end
          namespace_cache[project_file] = namespace
          return namespace
        end
      end
    end
  end
  local fallback = vim.fn.fnamemodify(project_file, ":t:r")
  namespace_cache[project_file] = fallback
  return fallback
end

local function create(event)
  local filename = vim.api.nvim_buf_get_name(event.buf)
  -- BufReadPost is included so `touch NewClass.cs` works too; only empty
  -- files receive a namespace, summary, and type skeleton.
  if event.event == "BufReadPost" and vim.fn.getfsize(filename) ~= 0 then return end
  if vim.api.nvim_buf_get_lines(event.buf, 0, -1, false)[1] ~= "" then return end

  local file_dir = vim.fs.dirname(filename)
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
  local class_name = vim.fn.fnamemodify(filename, ":t:r"):gsub("[^%w_]", "_")
  if class_name:match("^%d") then class_name = "_" .. class_name end
  local declaration = class_name:match("^I[A-Z]")
      and "public interface " .. class_name
    or "public class " .. class_name .. "()"
  vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, {
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
  vim.api.nvim_win_set_cursor(0, { 4, 4 })
  vim.cmd("startinsert")
  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.keycode("<Right>"), "n", false)
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
