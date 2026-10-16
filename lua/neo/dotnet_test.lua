-- Runs the test (or the class) under the cursor with `dotnet test --filter`. The name is built from
-- the Tree-sitter tree, so it does not depend on the test framework's attributes.
local M = {}

local TYPE_NODES = {
  class_declaration = true,
  struct_declaration = true,
  record_declaration = true,
  record_struct_declaration = true,
  interface_declaration = true,
}

local function name_of(node, buf)
  local name_node = node:field("name")[1]
  return name_node and vim.treesitter.get_node_text(name_node, buf) or nil
end

-- A file-scoped namespace (`namespace A.B;`) is a sibling of the declarations it covers, so it is
-- looked up on the compilation unit instead of among the ancestors.
local function file_scoped_namespace(root, buf, row)
  for child in root:iter_children() do
    if child:type() == "file_scoped_namespace_declaration" then
      local start_row = child:start()
      if start_row <= row then return name_of(child, buf) end
    end
  end
end

-- Returns { name = "Ns.Outer+Inner.Method", kind = "method" | "class" } for a position, or nil when
-- the position is not inside a type. Nested types are joined with "+", as VSTest names them.
function M.test_name(buf, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "c_sharp")
  if not ok or not parser then return nil end
  local root = parser:parse()[1]:root()
  local node = root:named_descendant_for_range(row, col, row, col)

  local method, types, namespaces = nil, {}, {}
  while node do
    local node_type = node:type()
    if node_type == "method_declaration" and not method then
      method = name_of(node, buf)
    elseif TYPE_NODES[node_type] then
      table.insert(types, 1, name_of(node, buf))
    elseif node_type == "namespace_declaration" then
      table.insert(namespaces, 1, name_of(node, buf))
    end
    node = node:parent()
  end
  if #types == 0 then return nil end

  local namespace = #namespaces > 0 and table.concat(namespaces, ".") or file_scoped_namespace(root, buf, row)
  local name = table.concat(types, "+")
  if namespace then name = namespace .. "." .. name end
  if method then return { name = name .. "." .. method, kind = "method" } end
  return { name = name, kind = "class" }
end

-- The nearest project above the file (the test project is where test files live).
function M.find_project(start_dir)
  return vim.fs.find(function(name) return name:sub(-7) == ".csproj" end, { path = start_dir, upward = true, limit = 1 })[1]
end

-- "~" means "contains", so a plain `~Ns.Class.Adds` would also run Adds2 and Ns.Class.Adds in other
-- classes. A method is therefore matched exactly (xUnit/MSTest names omit the arguments) or followed by
-- "(" (NUnit appends them). A class is matched as `Class.` (its methods) or `Class+` (nested classes).
function M.filter(target)
  local name = target.name
  if target.kind == "method" then
    return string.format("FullyQualifiedName=%s|FullyQualifiedName~%s\\(", name, name)
  end
  return string.format("FullyQualifiedName~%s.|FullyQualifiedName~%s+", name, name)
end

function M.command(project, target)
  return string.format("dotnet test %s --filter %s", vim.fn.shellescape(project), vim.fn.shellescape(M.filter(target)))
end

-- Replaced in tests; the default sends the command to the built-in terminal.
function M.runner(command) require("neo.terminal").run(command) end

function M.run()
  if vim.bo.filetype ~= "cs" then
    vim.notify("Running a test is only available in C# files.", vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local target = M.test_name(buf, row - 1, col)
  if not target then
    vim.notify("Place the cursor inside a test method or class.", vim.log.levels.WARN)
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  local project = M.find_project(vim.fs.dirname(file))
  if not project then
    vim.notify("No .csproj found above " .. vim.fs.basename(file) .. ".", vim.log.levels.WARN)
    return
  end
  vim.notify(string.format("Running %s %s", target.kind, target.name), vim.log.levels.INFO)
  M.runner(M.command(project, target))
end

function M.setup()
  vim.keymap.set("n", "<leader>rt", M.run, { desc = "Test: Run test or class at cursor" })
end

return M
