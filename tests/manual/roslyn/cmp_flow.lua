-- Types a prefix in insert mode, confirms the first matching nvim-cmp entry and
-- prints the line and cursor column, i.e. the real cmp + call_parens + Roslyn path.
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
local lib = require("lib")

local co
local function sleep(ms)
  vim.defer_fn(function() coroutine.resume(co) end, ms)
  coroutine.yield()
end
local function wait_until(predicate, ms)
  local waited = 0
  while not predicate() and waited < ms do
    sleep(50)
    waited = waited + 50
  end
end
local function keys(sequence) vim.api.nvim_feedkeys(vim.keycode(sequence), "n", false) end

co = coroutine.create(function()
  local ok, err = pcall(function()
    local _, buf, marker = lib.open()
    local cmp = require("cmp")
    -- { typed text, label prefix, exact label required }
    local cases = {
      { "l.Selec", "Select" }, { "l.Wher", "Where" }, { "f.Ge", "Gen" }, { "f.Zer", "Zero" },
      { "f.On", "One" }, { "Console.WriteLi", "WriteLine" },
      { "var a = new Fo", "Foo", true }, { "var b = new Ba", "Bar", true },
      { "var t = typeo", "typeof", true }, { "var n = namo", "nameof", true }, { "var z = sizeo", "sizeof", true },
      { "var d = defa", "default", true }, { "var k = ne", "new", true },
    }
    for _, case in ipairs(cases) do
      keys("<Esc>")
      sleep(100)
      vim.api.nvim_buf_set_lines(buf, marker, marker + 1, false, { "        " .. case[1] })
      vim.api.nvim_win_set_cursor(0, { marker + 1, 0 })
      keys("A")
      sleep(400)
      cmp.complete()
      wait_until(function() return cmp.visible() end, 6000)

      local index
      for position, entry in ipairs(cmp.get_entries() or {}) do
        local label = entry:get_completion_item().label
        if label:find("^" .. case[2]) and (not case[3] or label == case[2]) then
          index = position
          break
        end
      end
      if not index then
        lib.log(case[1], "-> no matching entry")
      else
        for _ = 1, index do cmp.select_next_item({ behavior = cmp.SelectBehavior.Select }) end
        sleep(1500) -- let cmp resolve the selected entry
        cmp.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })
        sleep(1200)
        local line = vim.api.nvim_get_current_line()
        lib.log(string.format("%-18s -> %-30s cursor col %d (line length %d)", case[1], line:sub(9),
          vim.api.nvim_win_get_cursor(0)[2], #line))
      end
    end
  end)
  if not ok then lib.log("ERROR", err) end
  vim.cmd("qa!")
end)
vim.defer_fn(function() coroutine.resume(co) end, 100)
