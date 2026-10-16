-- Asks Roslyn for signatureHelp right after "()" and prints the parameter counts
-- per signature, the same question neo.call_parens asks.
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
local lib = require("lib")

local ok, err = pcall(function()
  local client, buf, marker = lib.open()
  local uri = vim.uri_from_bufnr(buf)

  local cases = {
    "f.Zero", "f.One", "f.Over", "f.Gen", "f.ExtZero", "f.ExtOne", "Console.WriteLine",
    "l.Clear", "l.Add", "var a = new Foo", "var b = new Bar", "var c = new Baz",
  }
  for _, text in ipairs(cases) do
    local line = "        " .. text
    vim.api.nvim_buf_set_lines(buf, marker, marker + 1, false, { line .. "()" })
    local response
    local started = vim.uv.hrtime()
    client:request("textDocument/signatureHelp", {
      textDocument = { uri = uri },
      position = { line = marker, character = #line + 1 },
      context = { triggerKind = 2, triggerCharacter = "(", isRetrigger = false },
    }, function(_, result) response = result or false end, buf)
    vim.wait(6000, function() return response ~= nil end, 20)

    local counts = {}
    for _, signature in ipairs(response and response.signatures or {}) do
      table.insert(counts, #(signature.parameters or {}))
    end
    lib.log(string.format("%-20s %5.1f ms  parameters per signature: %s", text,
      (vim.uv.hrtime() - started) / 1e6, #counts > 0 and table.concat(counts, ",") or "none"))
  end
end)
if not ok then lib.log("ERROR", err) end
vim.cmd("qa!")
