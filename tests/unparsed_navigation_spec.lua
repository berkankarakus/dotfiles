-- The structural motions are global mappings, so they also fire in buffers whose language has no
-- Tree-sitter parser, or a parser without the matching captures (JSON only knows blocks and
-- parameters). They must be a quiet no-op there.
local function press(key, mode)
  local mapping = vim.fn.maparg(key, mode, false, true)
  assert(mapping and mapping.callback, "missing Lua mapping for " .. key)
  return pcall(mapping.callback)
end

local keys = { "]f", "[f", "]F", "[F", "]a", "[a", "]c", "[C", "]r", "[r", "]k", "[k", "]s", "[s", "]K", "[K" }

for _, filetype in ipairs({ "text", "conf" }) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{", '  "name": "value",', '  "other": [1, 2]', "}" })
  vim.bo.filetype = filetype
  assert(vim.treesitter.get_parser(0, nil, { error = false }) == nil, filetype .. " should have no parser here")

  for _, key in ipairs(keys) do
    vim.api.nvim_win_set_cursor(0, { 2, 4 })
    local ok, err = press(key, "n")
    assert(ok, string.format("%s in a %s buffer raised: %s", key, filetype, tostring(err)))
    assert(vim.deep_equal({ 2, 4 }, vim.api.nvim_win_get_cursor(0)),
      string.format("%s in a %s buffer should not move the cursor", key, filetype))
  end
end

-- JSON has a parser and textobjects query but no function/conditional/statement/switch captures.
-- ]k/[k and ]r/[r do move there (see json_textobjects_spec), the rest must stay quiet.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{", '  "name": "value",', '  "other": [1, 2]', "}" })
vim.bo.filetype = "json"
assert(vim.treesitter.get_parser(0, nil, { error = false }) ~= nil, "json should have a parser installed")
local json_quiet_keys = vim.tbl_filter(function(key) return not key:match("^[%[%]][kr]$") end, keys)
for _, key in ipairs(json_quiet_keys) do
  vim.api.nvim_win_set_cursor(0, { 2, 4 })
  local ok, err = press(key, "n")
  assert(ok, string.format("%s in a json buffer raised: %s", key, tostring(err)))
  assert(vim.deep_equal({ 2, 4 }, vim.api.nvim_win_get_cursor(0)), key .. " in a json buffer should not move the cursor")
end

-- Selection mappings (operator-pending / visual) must not raise either.
for _, filetype in ipairs({ "json", "text" }) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{", '  "name": "value",', "}" })
  vim.bo.filetype = filetype
  for _, key in ipairs({ "af", "if", "ac", "aa", "aq", "aS" }) do
    for _, mode in ipairs({ "x", "o" }) do
      local ok, err = press(key, mode)
      assert(ok, string.format("%s (%s) in a %s buffer raised: %s", key, mode, filetype, tostring(err)))
    end
  end
end

print("unparsed_navigation_spec: ok")
vim.cmd("qa!")
