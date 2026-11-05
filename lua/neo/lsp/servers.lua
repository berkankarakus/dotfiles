local M = {}

function M.setup()
  local capabilities = require("cmp_nvim_lsp").default_capabilities()
  capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
  vim.lsp.config("roslyn", {
    capabilities = capabilities,
    cmd = { vim.fn.expand("~/.dotnet/tools/roslyn-language-server"), "--stdio" },
    commands = {
      ["roslyn.client.nestedCodeAction"] = function(data, ctx)
        local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
        local nested_actions = data.arguments[1].NestedCodeActions or {}
        local code_actions = vim.tbl_map(function(code_action)
          local action_data = code_action.data
          local path = action_data.CodeActionPath
          local title = #path == 1 and path[1] or table.concat(path, " -> ", 2)
          if action_data.FixAllFlavors then title = "Fix All: " .. title end
          return { title = title, code_action = code_action }
        end, nested_actions)

        vim.ui.select(code_actions, {
          prompt = data.arguments[1].UniqueIdentifier,
          format_item = function(action) return action.title end,
        }, function(action)
          if not action then return end

          if action.code_action.data.FixAllFlavors then
            vim.lsp.config.roslyn.commands["roslyn.client.fixAllCodeAction"](action.code_action.command, ctx)
            return
          end

          client:request("codeAction/resolve", {
            title = action.code_action.title,
            data = action.code_action.data,
          }, function(err, response)
            if err then vim.notify(err.message, vim.log.levels.ERROR, { title = "roslyn.nvim" }) end
            if response and response.edit then
              vim.lsp.util.apply_workspace_edit(response.edit, client.offset_encoding)
            end
          end)
        end)
      end,
    },
    settings = {
      ["csharp|background_analysis"] = {
        dotnet_analyzer_diagnostics_scope = "openFiles",
        dotnet_compiler_diagnostics_scope = "openFiles",
      },
      ["csharp|inlay_hints"] = {
        csharp_enable_inlay_hints_for_lambda_parameter_types = true,
        dotnet_enable_inlay_hints_for_parameters = true,
      },
      ["csharp|completion"] = { dotnet_show_completion_items_from_unimported_namespaces = true },
    },
  })
  vim.lsp.enable("roslyn")

  -- The Elm server definition (nvim-lspconfig's lsp/elmls.lua) lives here so that plugin is not needed.
  vim.lsp.config("elmls", {
    cmd = { "elm-language-server" },
    filetypes = { "elm" },
    root_dir = function(bufnr, on_dir)
      local file = vim.api.nvim_buf_get_name(bufnr)
      local filetype = vim.bo[bufnr].filetype
      if filetype == "elm" or (filetype == "json" and file:match("elm%.json$")) then
        on_dir(vim.fs.root(file, "elm.json"))
        return
      end
      on_dir(nil)
    end,
    init_options = {
      elmReviewDiagnostics = "off",
      skipInstallPackageConfirmation = false,
      disableElmLSDiagnostics = false,
      onlyUpdateDiagnosticsOnSave = false,
    },
    capabilities = vim.tbl_deep_extend("force", { offsetEncoding = { "utf-8", "utf-16" } }, capabilities),
  })
  vim.lsp.enable("elmls")
end

return M
