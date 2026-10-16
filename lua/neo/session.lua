local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(event)
      if vim.bo[event.buf].buftype ~= "" or vim.bo[event.buf].filetype == "gitcommit" then return end
      if vim.api.nvim_win_get_buf(0) ~= event.buf then return end
      local last_position = vim.api.nvim_buf_get_mark(event.buf, '"')
      if last_position[1] > 0 and last_position[1] <= vim.api.nvim_buf_line_count(event.buf) then
        vim.api.nvim_win_set_cursor(0, last_position)
      end
    end,
  })

  local autosave_group = vim.api.nvim_create_augroup("SaveModifiedFileOnLeave", { clear = true })
  vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
    group = autosave_group,
    callback = function(event)
      local options = vim.bo[event.buf]
      if not options.modified or options.readonly or not options.modifiable or options.buftype ~= "" then return end
      if vim.api.nvim_buf_get_name(event.buf) == "" then return end
      vim.api.nvim_buf_call(event.buf, function() vim.cmd("silent update") end)
    end,
  })

  local last_file_state = vim.fn.stdpath("state") .. "/last-file-by-directory.json"
  local last_files
  local function project_key()
    return vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
  end
  local function read_last_files()
    if last_files then return last_files end
    local read_ok, lines = pcall(vim.fn.readfile, last_file_state)
    if not read_ok then
      last_files = {}
      return last_files
    end
    local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
    last_files = decode_ok and type(decoded) == "table" and decoded or {}
    return last_files
  end
  local function remember_last_file(event)
    if vim.bo[event.buf].buftype ~= "" then return end
    local file = vim.api.nvim_buf_get_name(event.buf)
    if file == "" or vim.fn.filereadable(file) == 0 then return end
    local root = project_key()
    local resolved_file = vim.uv.fs_realpath(file) or file
    if resolved_file:sub(1, #root + 1) ~= root .. "/" then return end
    local files = read_last_files()
    if files[root] == resolved_file then return end
    local previous_file = files[root]
    files[root] = resolved_file
    local write_ok = pcall(vim.fn.writefile, { vim.json.encode(files) }, last_file_state)
    if not write_ok then files[root] = previous_file end
  end
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, { callback = remember_last_file })

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if vim.fn.argc() ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) == 0 then return end
      local root = project_key()
      local file = read_last_files()[root]
      if not file or vim.fn.filereadable(file) == 0 then
        for _, old_file in ipairs(vim.v.oldfiles) do
          local resolved_file = vim.uv.fs_realpath(old_file) or old_file
          if resolved_file:sub(1, #root + 1) == root .. "/" and vim.fn.filereadable(resolved_file) == 1 then
            file = resolved_file
            break
          end
        end
      end
      if file then vim.schedule(function() vim.cmd.edit(vim.fn.fnameescape(file)) end) end
    end,
  })
end

return M
