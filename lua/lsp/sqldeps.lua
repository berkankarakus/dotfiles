-- sqldeps exposes SQL object navigation through its stdio LSP server.
return {
  cmd = { "sqldeps", "lsp" },
  filetypes = { "sql" },
  root_dir = function(bufnr, on_dir)
    local configured_root = vim.g.sqldeps_root
    if type(configured_root) == "string" and configured_root ~= "" and vim.fn.isdirectory(configured_root) == 1 then
      on_dir(vim.fs.normalize(vim.fn.fnamemodify(configured_root, ":p")))
      return
    end

    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return end

    on_dir(vim.fs.root(file, ".git") or vim.fs.dirname(file))
  end,
}
