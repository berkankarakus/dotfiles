-- Confirms real nvim-cmp entries, finishes the argument the way a user would, then checks the
-- result: tree-sitter must report no syntax error and `dotnet build` must succeed.
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
local function keys(sequence, mode) vim.api.nvim_feedkeys(vim.keycode(sequence), mode or "n", false) end

co = coroutine.create(function()
  local ok, err = pcall(function()
    local _, buf, marker = lib.open()
    local cmp = require("cmp")
    local parser = vim.treesitter.get_parser(buf, "c_sharp")
    -- { typed text, label prefix, exact label required, what the user types next, tail,
    --   optional key to press afterwards, what is typed after it }
    local cases = {
      { "f.Sa", "Say", false, "hi" },
      { "f.Se", "Sep", false, "x" },
      { "f.Ea", "Each", false, "Console.WriteLine(x)" },
      { "f.Or", "Ordr", false, "a - b" },
      { "f.Fo", "Fold", false, "a + b", ";" },
      { "l.Whe", "Where", false, "n => n > 1", ";" },
      { "f.Zer", "Zero", false, "" },
      { "f.On", "One", false, "1" },
      { "f.Ov", "Over", false, "" },
      { "var a = new in", "int", true, "3", ";" },
      { "var s = new str", "string", true, "3", ";" },
      { "var g = new Lis", "List<>", true, "int>", ";" },
      { "var d = new Dictiona", "Dictionary<>", true, "string, List<int>>", ";" },
      { "var q = new Fo", "Foo", true, "", ";" },
      -- Option-Enter must supply the ";" on its own: no tail here.
      { "f.Fo", "Fold", false, "a + b", nil, "<M-CR>", "" },
      { "var r = f.Fo", "Fold", false, "a * b", nil, "<M-CR>", "" },
      { "l.Whe", "Where", false, "n => n > 1", nil, "<M-CR>", "" },
      { "var k = l.Cou", "Count", false, "", nil, "<M-CR>", "" },
      { "var h = new HashS", "HashSet<>", true, "int>", ";", "<M-i>", "1, 2" },
      { "var m = new Dictiona", "Dictionary<>", true, "int, string>", ";", "<M-i>", '{ 1, "a" }' },
    }
    local failures = 0
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
        if label:sub(1, #case[2]) == case[2] and (not case[3] or label == case[2]) then
          index = position
          break
        end
      end
      if not index then
        local labels = {}
        for position, entry in ipairs(cmp.get_entries() or {}) do
          if position <= 8 then labels[#labels + 1] = entry:get_completion_item().label end
        end
        lib.log(case[1], "-> no matching entry; first entries:", table.concat(labels, " | "))
        failures = failures + 1
      else
        for _ = 1, index do cmp.select_next_item({ behavior = cmp.SelectBehavior.Select }) end
        sleep(1500)
        cmp.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })
        sleep(1200)
        local after_confirm = vim.api.nvim_get_current_line():sub(9)
        local column = vim.api.nvim_win_get_cursor(0)[2]
        -- One key at a time with a pause, as a person types; a burst races nvim-cmp's own handling.
        for character in case[4]:gmatch(".") do
          keys(character, "m")
          sleep(150)
        end
        if case[6] then
          keys(case[6], "m")
          sleep(200)
          for character in case[7]:gmatch(".") do
            keys(character, "m")
            sleep(150)
          end
        end
        sleep(300)
        local line = vim.api.nvim_get_current_line()
        if not line:find(";%s*$") then
          vim.api.nvim_buf_set_lines(buf, marker, marker + 1, false, { line .. (case[5] or "") })
        end
        keys("<Esc>")
        sleep(200)
        vim.cmd("silent write")
        local tree = parser:parse(true)[1]
        local syntax_ok = not tree:root():has_error()
        local build = vim.system({ "dotnet", "build", "-nologo", "-v", "q", "-clp:ErrorsOnly" }, { text = true }):wait(60000)
        local build_ok = build.code == 0
        if not (syntax_ok and build_ok) then failures = failures + 1 end
        lib.log(string.format("%-22s -> %-34s cursor %2d | %s | syntax %s | build %s", case[1], after_confirm, column,
          vim.api.nvim_get_current_line():sub(9), syntax_ok and "ok" or "ERROR", build_ok and "ok" or "FAIL"))
        if not build_ok then lib.log((build.stdout or ""):sub(1, 400)) end
      end
    end

    -- Option-Enter on rows that must stay as they are, and on rows that must gain a ";".
    -- "|" marks the cursor; the row is compared after the key.
    local rows = {
      { "if (f|)", "if (f)" },
      { "for (int i = 0; i < 3; i++|)", "for (int i = 0; i < 3; i++)" },
      { "while (running|)", "while (running)" },
      { "foreach (var n in l|)", "foreach (var n in l)" },
      { "foo.Bar(1,|", "foo.Bar(1," },
      { "var fn = x =>|", "var fn = x =>" },
      { "else|", "else" },
      { "try|", "try" },
      { "f.Zero();|", "f.Zero();" },
      { "f.Zero(|)", "f.Zero();" },
      { "var t = (1, 2|)", "var t = (1, 2);" },
      { "l.Add(l.Count(|))", "l.Add(l.Count());" },
      { "return f.Fold((a, b) => a + b|)", "return f.Fold((a, b) => a + b);" },
      { "var a = new int[l.Count(|)]", "var a = new int[l.Count()];" },
      { "f.Zero()|  // done", "f.Zero();  // done" },
    }
    for _, row in ipairs(rows) do
      keys("<Esc>")
      sleep(100)
      local column = row[1]:find("|", 1, true) - 1
      local text = row[1]:gsub("|", "", 1)
      vim.api.nvim_buf_set_lines(buf, marker, marker + 1, false, { "        " .. text })
      keys("A")
      sleep(200)
      vim.api.nvim_win_set_cursor(0, { marker + 1, 8 + column })
      keys("<M-CR>", "m")
      sleep(500)
      local actual = vim.api.nvim_get_current_line():sub(9)
      local passed = actual == row[2]
      if not passed then failures = failures + 1 end
      lib.log(string.format("%-4s %-40s -> %s", passed and "ok" or "FAIL", row[1], actual))
    end
    keys("<Esc>")
    lib.log("failures: " .. failures)
  end)
  if not ok then lib.log("ERROR", err) end
  vim.cmd("qa!")
end)
vim.defer_fn(function() coroutine.resume(co) end, 100)
