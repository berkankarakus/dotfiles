-- Navigate a sqldeps SQLite index from SQL buffers without replacing C# LSP navigation.
local M = {}

local function configured_path(name)
  return vim.fs.normalize(vim.fn.expand(name))
end

local function index_path()
  if type(vim.g.sqldeps_database) == "string" and vim.g.sqldeps_database ~= "" then
    return configured_path(vim.g.sqldeps_database)
  end

  local root = vim.fn.getcwd()
  local name = vim.fs.basename(root)

  return vim.fs.joinpath(vim.fn.expand("~/.local/share/sqldeps"), name .. ".sqlite")
end

local function source_root()
  if type(vim.g.sqldeps_root) == "string" and vim.g.sqldeps_root ~= "" then
    return configured_path(vim.g.sqldeps_root)
  end

  return vim.fn.getcwd()
end

local function identifier_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local column = vim.api.nvim_win_get_cursor(0)[2] + 1
  local allowed = "[%w_#%[%]%.]"
  local first = column
  local last = column

  while first > 1 and line:sub(first - 1, first - 1):match(allowed) do
    first = first - 1
  end

  while last <= #line and line:sub(last, last):match(allowed) do
    last = last + 1
  end

  local identifier = line:sub(first, last - 1):gsub("%[([^%]]+)%]", "%1")

  return identifier ~= "" and identifier or nil
end

local function object_name(argument)
  local value = argument ~= "" and argument or identifier_under_cursor()

  if not value then
    vim.notify("Place the cursor on a SQL object name or pass one to the command.", vim.log.levels.WARN)
    return nil
  end

  return value:gsub("%[([^%]]+)%]", "%1")
end

local function quote(value)
  return "'" .. value:gsub("'", "''") .. "'"
end

local function quickfix_path(root, source_file)
  if source_file:sub(1, 1) == "/" then
    return source_file
  end

  return vim.fs.joinpath(root, source_file)
end

local function show_results(title, root, rows, text_for_row)
  if #rows == 0 then
    vim.notify("sqldeps: no results.", vim.log.levels.INFO)
    return
  end

  local items = vim.tbl_map(function(row)
    return {
      filename = quickfix_path(root, row.source_file),
      lnum = row.line,
      col = 1,
      text = text_for_row(row),
    }
  end, rows)
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd("copen")
end

local function run_query(sql, callback)
  local database = index_path()

  if vim.fn.executable("sqlite3") ~= 1 then
    vim.notify("sqldeps needs the sqlite3 command-line tool.", vim.log.levels.ERROR)
    return
  end

  if not vim.uv.fs_stat(database) then
    vim.notify("sqldeps index not found: " .. database .. ". Run sqldeps index first.", vim.log.levels.WARN)
    return
  end

  vim.system({ "sqlite3", "-json", database, sql }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.notify("sqldeps query failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
      return
    end

    local ok, rows = pcall(vim.json.decode, result.stdout == "" and "[]" or result.stdout)
    if not ok or type(rows) ~= "table" then
      vim.notify("sqldeps returned invalid JSON.", vim.log.levels.ERROR)
      return
    end

    callback(rows)
  end)
end

local function definition_query(name, callback)
  run_query(
    "SELECT name, kind, source_file, line FROM objects WHERE name = " .. quote(name) .. " COLLATE NOCASE ORDER BY source_file, line",
    callback
  )
end

function M.definition(argument)
  local name = object_name(argument)
  if not name then return end

  definition_query(name, function(rows)
    show_results("sqldeps definition: " .. name, source_root(), rows, function(row)
      return string.format("%s %s", row.kind, row.name)
    end)
  end)
end

function M.open_definition(argument)
  local name = object_name(argument)
  if not name then return end

  definition_query(name, function(rows)
    if #rows ~= 1 then
      show_results("sqldeps definition: " .. name, source_root(), rows, function(row)
        return string.format("%s %s", row.kind, row.name)
      end)
      return
    end

    local row = rows[1]
    local source_file = quickfix_path(source_root(), row.source_file)
    if not vim.uv.fs_stat(source_file) then
      vim.notify("sqldeps source file not found: " .. source_file, vim.log.levels.WARN)
      return
    end

    local command = vim.bo.modified and "vsplit " or "edit "
    vim.cmd(command .. vim.fn.fnameescape(source_file))
    vim.api.nvim_win_set_cursor(0, { row.line, 0 })
  end)
end

function M.references(argument)
  local name = object_name(argument)
  if not name then return end

  run_query(
    "SELECT source_object, operation, source_file, line FROM dependencies WHERE target_object = " .. quote(name) .. " COLLATE NOCASE AND source_object <> '(batch)' ORDER BY source_file, line",
    function(rows)
      show_results("sqldeps references: " .. name, source_root(), rows, function(row)
        return string.format("%s %s -> %s", row.source_object, row.operation, name)
      end)
    end
  )
end

function M.setup()
  vim.api.nvim_create_user_command("SqlDef", function(command)
    M.definition(command.args)
  end, { nargs = "?", force = true, desc = "Open sqldeps definitions in quickfix" })
  vim.api.nvim_create_user_command("SqlRefs", function(command)
    M.references(command.args)
  end, { nargs = "?", force = true, desc = "Open sqldeps references in quickfix" })
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("SqlDepsCSharpNavigation", { clear = true }),
    pattern = "cs",
    callback = function(event)
      vim.keymap.set("n", "<leader>cs", function()
        M.open_definition("")
      end, { buffer = event.buf, desc = "Open SQL procedure definition" })
    end,
  })
end

return M
