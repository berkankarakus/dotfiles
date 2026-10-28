local function assert_equal(expected, actual, message)
  assert(expected == actual, string.format("%s (expected %s, got %s)", message, vim.inspect(expected), vim.inspect(actual)))
end

require("lazy").load({ plugins = { "roslyn.nvim" } })

local buffer = vim.api.nvim_get_current_buf()
vim.bo[buffer].filetype = "cs"
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "Call(value)" })
vim.api.nvim_win_set_cursor(0, { 1, 5 })

local old_get_client = vim.lsp.get_client_by_id
local old_request = vim.lsp.buf_request
local old_preview = vim.lsp.util.open_floating_preview
vim.lsp.get_client_by_id = function()
  return { offset_encoding = "utf-16", server_capabilities = {} }
end

local titles = {}
vim.lsp.buf_request = function(_, _, _, callback)
  callback(nil, {
    activeSignature = 0,
    signatures = {
      { label = "Call(string value)" },
      { label = "Call(int value)" },
      { label = "Call(bool value)" },
    },
  })
end
vim.lsp.util.open_floating_preview = function(_, _, options)
  table.insert(titles, options.title)
end

vim.api.nvim_exec_autocmds("LspAttach", { buffer = buffer, data = { client_id = 999 } })

local function callback_for(lhs, mode)
  local mapping = vim.fn.maparg(lhs, mode, false, true)
  assert(type(mapping.callback) == "function", lhs .. " should be mapped in " .. mode .. " mode")
  return mapping.callback
end

local forward = callback_for("<M-s>", "n")
local backward = callback_for("<M-S>", "n")
callback_for("<M-s>", "i")
callback_for("<M-S>", "i")

forward()
forward()
forward()
forward()
assert_equal(" Overload 1/3 ", titles[1], "forward starts at the active overload")
assert_equal(" Overload 2/3 ", titles[2], "forward advances")
assert_equal(" Overload 3/3 ", titles[3], "forward advances again")
assert_equal(" Overload 1/3 ", titles[4], "forward wraps")

backward()
backward()
backward()
assert_equal(" Overload 3/3 ", titles[5], "backward wraps from the first overload")
assert_equal(" Overload 2/3 ", titles[6], "backward advances")
assert_equal(" Overload 1/3 ", titles[7], "backward wraps to the first overload")

vim.api.nvim_win_set_cursor(0, { 1, 6 })
forward()
assert_equal(" Overload 1/3 ", titles[8], "moving the cursor resets the overload cycle")

vim.lsp.get_client_by_id = old_get_client
vim.lsp.buf_request = old_request
vim.lsp.util.open_floating_preview = old_preview

print("signature_cycle_spec: ok")
