-- SQL LSP setup and Neovim commands for sqldeps. SQLite-backed queries live in sqldeps.query.
local query = require("neo.sqldeps.query")

local M = {
  definition = query.definition,
  open_definition = query.open_definition,
  references = query.references,
  columns = query.columns,
}

function M.setup()
  vim.lsp.config("sqldeps-lsp", require("lsp.sqldeps"))
  vim.lsp.enable("sqldeps-lsp")

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("SqlDepsLspKeymaps", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client or client.name ~= "sqldeps-lsp" or vim.bo[event.buf].filetype ~= "sql" then return end

      local map = function(keys, action, description)
        vim.keymap.set("n", keys, action, { buffer = event.buf, desc = description })
      end
      map("gd", vim.lsp.buf.definition, "SQL definition")
      map("gr", vim.lsp.buf.references, "SQL references")
      map("K", vim.lsp.buf.hover, "SQL documentation")
      map("<leader>ds", vim.lsp.buf.document_symbol, "SQL document symbols")
      map("<leader>ws", vim.lsp.buf.workspace_symbol, "SQL workspace symbols")
      map("<leader>ca", vim.lsp.buf.code_action, "SQL code action")
      map("<leader>e", vim.diagnostic.open_float, "SQL diagnostics")
      map("<leader>y", function()
        local diagnostics = vim.diagnostic.get(event.buf, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
        if #diagnostics == 0 then
          vim.notify("No diagnostics on this line.", vim.log.levels.INFO)
          return
        end
        vim.fn.setreg("+", table.concat(vim.tbl_map(function(diagnostic) return diagnostic.message end, diagnostics), "\n"))
        vim.notify("Diagnostic copied.", vim.log.levels.INFO)
      end, "Copy SQL diagnostic")
    end,
  })

  vim.api.nvim_create_user_command("SqlDef", function(command)
    M.definition(command.args)
  end, { nargs = "?", force = true, desc = "Open sqldeps definitions in quickfix" })
  vim.api.nvim_create_user_command("SqlRefs", function(command)
    M.references(command.args)
  end, { nargs = "?", force = true, desc = "Open sqldeps references in quickfix" })
  vim.api.nvim_create_user_command("SqlColumns", function(command)
    M.columns(command.args)
  end, { nargs = "?", force = true, desc = "Open sqldeps column usage in quickfix" })
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
