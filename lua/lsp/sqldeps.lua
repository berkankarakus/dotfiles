-- sqldeps exposes SQL object navigation through its stdio LSP server.
return {
  cmd = { "sqldeps", "lsp" },
  filetypes = { "sql" },
  root_dir = function(bufnr, on_dir)
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return end

    on_dir(vim.fs.root(file, ".git") or vim.fs.dirname(file))
  end,
}
