-- Language servers (Roslyn, Elm), LSP keymaps and formatting.
return {
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "seblyng/roslyn.nvim",
    dependencies = { "neovim/nvim-lspconfig" },
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
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
    vim.lsp.config("elmls", {
      capabilities = capabilities,
    })
    vim.lsp.enable("elmls")
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and vim.bo[event.buf].filetype == "cs" and client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
          end
          local code_action = function()
            vim.lsp.buf.code_action()
          end
          local signature_state = {}
          local function show_next_signature()
            local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
            vim.lsp.buf_request(event.buf, "textDocument/signatureHelp", params, function(err, result)
              if err or not result or not result.signatures or #result.signatures == 0 then
                vim.notify("No signature available here.", vim.log.levels.INFO)
                return
              end

              local position = vim.api.nvim_win_get_cursor(0)
              local state_key = table.concat({ event.buf, position[1], position[2], #result.signatures }, ":")
              local signature_index
              if signature_state.key == state_key then
                signature_index = (signature_state.index + 1) % #result.signatures
              else
                signature_index = result.activeSignature or 0
              end
              signature_state = { key = state_key, index = signature_index }

              vim.lsp.util.open_floating_preview({ result.signatures[signature_index + 1].label }, "cs", {
                border = "rounded",
                title = string.format(" Overload %d/%d ", signature_index + 1, #result.signatures),
                focusable = false,
                focus_id = "csharp-signature-overload",
              })
            end)
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Documentation")
          map("<leader>s", show_next_signature, "Next overload")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          vim.keymap.set({ "n", "x" }, "<leader>ca", code_action, { buffer = event.buf, desc = "Code action" })
          map("<leader>cd", require("neo.csharp").insert_docstring, "Insert C# docstring")
          map("<leader>e", vim.diagnostic.open_float, "Diagnostics")
          map("<leader>y", function()
            local diagnostics = vim.diagnostic.get(event.buf, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
            if #diagnostics == 0 then
              vim.notify("No diagnostics on this line.", vim.log.levels.INFO)
              return
            end
            vim.fn.setreg("+", table.concat(vim.tbl_map(function(diagnostic) return diagnostic.message end, diagnostics), "\n"))
            vim.notify("Diagnostic copied.", vim.log.levels.INFO)
          end, "Copy diagnostic")
          if client and client.server_capabilities.documentHighlightProvider then
            local group = vim.api.nvim_create_augroup("LspDocumentHighlight" .. event.buf, { clear = true })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              group = group,
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              group = group,
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      -- C# formatting is delegated to Roslyn so project .editorconfig rules apply.
      formatters_by_ft = { elm = { "elm_format" } },
      format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
    },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "x" },
        desc = "Format buffer or selection",
      },
    },
  },
}
