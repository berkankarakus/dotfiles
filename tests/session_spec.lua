local function fail(message)
  error(message, 0)
end

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    fail((message or "values differ") .. string.format(" (expected %q, got %q)", expected, actual))
  end
end

vim.opt.rtp:prepend(vim.fn.getcwd())
require("neo.session").setup()

local project_dir = vim.fn.tempname()
vim.fn.mkdir(project_dir, "p")
local file = project_dir .. "/Program.cs"
vim.fn.writefile({ "class Program {}" }, file)
vim.cmd.cd(vim.fn.fnameescape(project_dir))

local state_file = vim.fn.stdpath("state") .. "/last-file-by-directory.json"
vim.fn.delete(state_file)

local original_writefile = vim.fn.writefile
local writes = 0
vim.fn.writefile = function(lines, path, ...)
  if path == state_file then writes = writes + 1 end
  return original_writefile(lines, path, ...)
end

vim.cmd.edit(vim.fn.fnameescape(file))
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = 0 })

vim.fn.writefile = original_writefile

assert_equal(1, writes, "unchanged last file should be persisted once")
local saved = vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n"))
local root = vim.uv.fs_realpath(project_dir) or project_dir
assert_equal(vim.uv.fs_realpath(file) or file, saved[root], "last file was not persisted")

vim.fn.delete(project_dir, "rf")
print("session_spec: ok")
