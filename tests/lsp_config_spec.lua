local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

-- The LSP setup runs from the roslyn.nvim spec; load it the way a C# file would.
local plugins = require("lazy.core.config").plugins
assert_equal(nil, plugins["nvim-lspconfig"], "nvim-lspconfig should no longer be a plugin")
require("lazy").load({ plugins = { "roslyn.nvim" } })

-- Roslyn
local roslyn = vim.lsp.config.roslyn
assert(roslyn, "the roslyn config should exist")
assert_equal("--stdio", roslyn.cmd[2], "Roslyn should run over stdio")
assert(roslyn.cmd[1]:find("roslyn-language-server", 1, true), "Roslyn should use the dotnet tool: " .. roslyn.cmd[1])
assert_equal("openFiles", roslyn.settings["csharp|background_analysis"].dotnet_analyzer_diagnostics_scope, "analysis stays on open files")
assert(roslyn.commands["roslyn.client.nestedCodeAction"], "the nested code action command should be registered")
assert_equal(false, roslyn.capabilities.textDocument.foldingRange.dynamicRegistration, "folding capabilities should be set")

-- Elm: everything nvim-lspconfig's lsp/elmls.lua used to provide
local elm = vim.lsp.config.elmls
assert_equal("elm-language-server", elm.cmd[1], "the Elm server command")
assert_equal("elm", elm.filetypes[1], "the Elm filetype")
assert_equal("off", elm.init_options.elmReviewDiagnostics, "the Elm init options")
assert_equal("utf-8", elm.capabilities.offsetEncoding[1], "the Elm offset encoding")
assert(elm.capabilities.textDocument.foldingRange, "the shared capabilities should reach Elm too")

local project = vim.fn.tempname()
vim.fn.mkdir(project .. "/src", "p")
vim.fn.writefile({ "{}" }, project .. "/elm.json")
vim.fn.writefile({ "module Main exposing (main)" }, project .. "/src/Main.elm")

local function root_for(file, filetype)
  local buf = vim.fn.bufadd(file)
  vim.fn.bufload(buf)
  vim.bo[buf].filetype = filetype
  local root
  elm.root_dir(buf, function(dir) root = dir end)
  return root
end

assert_equal(vim.uv.fs_realpath(project), vim.uv.fs_realpath(root_for(project .. "/src/Main.elm", "elm")), "an Elm file should find its elm.json root")
assert_equal(vim.uv.fs_realpath(project), vim.uv.fs_realpath(root_for(project .. "/elm.json", "json")), "elm.json itself should attach too")
vim.fn.writefile({ "{}" }, project .. "/other.json")
assert_equal(nil, root_for(project .. "/other.json", "json"), "other JSON files must not attach the Elm server")
vim.fn.delete(project, "rf")

-- The keymaps still attach with the language server.
assert_equal(true, #vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0, "an LspAttach handler should be registered")

print("lsp_config_spec: ok")
