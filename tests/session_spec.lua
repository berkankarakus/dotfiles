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

local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "class Updated {}" })
vim.api.nvim_exec_autocmds("FocusLost", { buffer = buffer })
assert_equal(false, vim.bo[buffer].modified, "focus loss should save a modified named file")
assert_equal("class Updated {}", vim.fn.readfile(file)[1], "focus-loss save should reach disk")

vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "class ReadOnly {}" })
vim.bo[buffer].readonly = true
vim.api.nvim_exec_autocmds("BufLeave", { buffer = buffer })
assert_equal(true, vim.bo[buffer].modified, "read-only buffers should not be autosaved")
vim.bo[buffer].readonly = false
vim.bo[buffer].modified = false

vim.api.nvim_buf_set_mark(buffer, '"', 1, 6, {})
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = buffer })
assert_equal(6, vim.api.nvim_win_get_cursor(0)[2], "reading a file should restore its last cursor column")

local commit_buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(commit_buffer, 0, -1, false, { "commit message" })
vim.api.nvim_win_set_buf(0, commit_buffer)
vim.bo[commit_buffer].filetype = "gitcommit"
vim.api.nvim_buf_set_mark(commit_buffer, '"', 1, 6, {})
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = commit_buffer })
assert_equal(0, vim.api.nvim_win_get_cursor(0)[2], "git commit buffers should not restore a file cursor mark")

vim.fn.delete(project_dir, "rf")
print("session_spec: ok")
