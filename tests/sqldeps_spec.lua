local sqldeps = require("neo.sqldeps")
local original_system = vim.system
local database = "/tmp/sqldeps-test.sqlite"
local root = vim.fn.tempname()

vim.fn.writefile({ "" }, database)
vim.fn.mkdir(root .. "/procedures", "p")
vim.fn.writefile({ "CREATE PROCEDURE dbo.UpdatePrices AS SELECT 1;" }, root .. "/procedures/prices.sql")
vim.g.sqldeps_database = database
vim.g.sqldeps_root = root
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "EXEC dbo.UpdatePrices;" })
vim.api.nvim_win_set_cursor(0, { 1, 10 })

local command
vim.system = function(arguments, _, callback)
  command = arguments
  callback({
    code = 0,
    stdout = '[{"name":"dbo.UpdatePrices","kind":"procedure","source_file":"procedures/prices.sql","line":12}]',
    stderr = "",
  })
end

sqldeps.definition("")
assert(command[1] == "sqlite3", "SqlDef should query through sqlite3")
assert(command[2] == "-json", "SqlDef should request JSON output")
assert(command[3] == database, "SqlDef should use the configured index")
assert(command[4]:find("objects WHERE name = 'dbo.UpdatePrices'", 1, true), "SqlDef should query the object under the cursor")
local definition = vim.fn.getqflist({ title = 0, items = 1 })
assert(definition.title == "sqldeps definition: dbo.UpdatePrices", "SqlDef should title quickfix")
assert(vim.api.nvim_buf_get_name(definition.items[1].bufnr) == vim.uv.fs_realpath(root .. "/procedures/prices.sql"), "SqlDef should resolve indexed paths")
assert(definition.items[1].lnum == 12, "SqlDef should preserve the definition line")

vim.system = function(arguments, _, callback)
  command = arguments
  callback({
    code = 0,
    stdout = '[{"source_object":"dbo.Report","operation":"SELECT","source_file":"reports.sql","line":8}]',
    stderr = "",
  })
end

sqldeps.references("dbo.Prices")
assert(command[4]:find("dependencies WHERE target_object = 'dbo.Prices'", 1, true), "SqlRefs should query dependencies")
local references = vim.fn.getqflist({ title = 0, items = 1 })
assert(references.title == "sqldeps references: dbo.Prices", "SqlRefs should title quickfix")
assert(references.items[1].text == "dbo.Report SELECT -> dbo.Prices", "SqlRefs should describe the reference")

vim.cmd("cclose")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'var command = "dbo.UpdatePrices";' })
vim.bo.filetype = "cs"
vim.api.nvim_win_set_cursor(0, { 1, 22 })
vim.bo.modified = false
assert(vim.fn.maparg("<leader>cs", "n", false, true).callback, "C# buffers should map Space c s")
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '[{"name":"dbo.UpdatePrices","kind":"procedure","source_file":"procedures/prices.sql","line":1}]',
    stderr = "",
  })
end

sqldeps.open_definition("")
assert(vim.api.nvim_buf_get_name(0) == vim.uv.fs_realpath(root .. "/procedures/prices.sql"), "Space c s should open the indexed procedure")
assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "Space c s should place the cursor on the definition")

vim.system = original_system
vim.g.sqldeps_database = nil
vim.g.sqldeps_root = nil
vim.fn.delete(database)
vim.fn.delete(root, "rf")
vim.cmd("qa!")
