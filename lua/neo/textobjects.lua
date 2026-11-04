-- Tree-sitter textobject selection and structural motions (functions, SQL clauses/queries,
-- C# statements and switch cases). Mappings are global, so every motion goes through
-- has_textobjects and is a quiet no-op in buffers without a parser or textobjects query.
local M = {}

local PRELOAD_KEYS = {
  { { "x", "o" }, "ab" }, { { "x", "o" }, "ib" }, { { "x", "o" }, "af" }, { { "x", "o" }, "if" },
  { { "x", "o" }, "al" }, { { "x", "o" }, "il" }, { { "x", "o" }, "aC" }, { { "x", "o" }, "iC" },
  { { "x", "o" }, "ac" }, { { "x", "o" }, "ic" }, { { "x", "o" }, "aa" }, { { "x", "o" }, "ia" },
  { { "x", "o" }, "aq" }, { { "x", "o" }, "aS" },
  { { "n", "x", "o" }, "]f" }, { { "n", "x", "o" }, "[f" }, { { "n", "x", "o" }, "]F" }, { { "n", "x", "o" }, "[F" },
  { { "n", "x", "o" }, "]a" }, { { "n", "x", "o" }, "[a" }, { { "n", "x", "o" }, "]c" }, { { "n", "x", "o" }, "[c" },
  { { "n", "x", "o" }, "]C" }, { { "n", "x", "o" }, "[C" }, { { "n", "x", "o" }, "]r" }, { { "n", "x", "o" }, "[r" },
  { { "n", "x", "o" }, "]k" }, { { "n", "x", "o" }, "[k" }, { { "n", "x", "o" }, "]s" }, { { "n", "x", "o" }, "[s" },
  { { "n", "x", "o" }, "]K" }, { { "n", "x", "o" }, "[K" },
}

-- Keep the global mappings harmless before the textobjects plugin is loaded by filetype.
function M.preload()
  for _, mapping in ipairs(PRELOAD_KEYS) do
    vim.keymap.set(mapping[1], mapping[2], function() end)
  end
end

function M.setup()
  require("nvim-treesitter-textobjects").setup({
    select = {
      lookahead = true,
      include_surrounding_whitespace = false,
    },
    move = { set_jumps = true },
  })

  local select = require("nvim-treesitter-textobjects.select")
  local move = require("nvim-treesitter-textobjects.move")
  local shared = require("nvim-treesitter-textobjects.shared")
  local capture_cache = {}
  -- The mappings below are global, so buffers whose language has no parser or no
  -- textobjects query must be a quiet no-op instead of an error inside the plugin.
  local function has_textobjects()
    local ok, parser = pcall(vim.treesitter.get_parser, 0)
    if not ok or not parser then return false end
    return vim.treesitter.query.get(parser:lang(), "textobjects") ~= nil
  end
  local function map_textobject(keys, query, desc)
    vim.keymap.set({ "x", "o" }, keys, function()
      if not has_textobjects() then return end
      select.select_textobject(query, "textobjects")
    end, { desc = desc })
  end
  local function goto_range(range, at_end)
    if not range or not range[1] then return end
    vim.cmd("normal! m'")
    if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end

    local row, column
    if at_end then
      row, column = range[4], range[5]
      if column == 0 then
        row = row - 1
        column = #vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
      else
        column = column - 1
      end
    else
      row, column = range[1], range[2]
    end
    vim.api.nvim_win_set_cursor(0, { row + 1, column })
  end
  local function move_with_wrap(query, forward, at_end, wrap)
    if not has_textobjects() then return end
    local cursor_before = vim.api.nvim_win_get_cursor(0)
    if forward and at_end then
      move.goto_next_end(query, "textobjects")
    elseif forward then
      move.goto_next_start(query, "textobjects")
    elseif at_end then
      move.goto_previous_end(query, "textobjects")
    else
      move.goto_previous_start(query, "textobjects")
    end
    if not vim.deep_equal(cursor_before, vim.api.nvim_win_get_cursor(0)) or not wrap then return end

    local range_index = at_end and 6 or 3
    local range = shared.find_best_range(0, query, "textobjects", function()
      return true
    end, function(candidate)
      return forward and -candidate[range_index] or candidate[range_index]
    end)
    goto_range(range, at_end)
  end
  local function map_textobject_move(next_start, previous_start, next_end, previous_end, query, desc)
    vim.keymap.set({ "n", "x", "o" }, next_start, function()
      move_with_wrap(query, true, false)
    end, { desc = "Next " .. desc })
    vim.keymap.set({ "n", "x", "o" }, previous_start, function()
      move_with_wrap(query, false, false)
    end, { desc = "Previous " .. desc })
    vim.keymap.set({ "n", "x", "o" }, next_end, function()
      move_with_wrap(query, true, true)
    end, { desc = "Next " .. desc .. " end" })
    vim.keymap.set({ "n", "x", "o" }, previous_end, function()
      move_with_wrap(query, false, true)
    end, { desc = "Previous " .. desc .. " end" })
  end
  local function map_textobject_start(next_start, previous_start, query, desc, only_csharp, wrap)
    local function allowed()
      return not only_csharp or vim.bo.filetype == "cs" or vim.bo.filetype == "c_sharp"
    end
    vim.keymap.set({ "n", "x", "o" }, next_start, function()
      if not allowed() then return end
      move_with_wrap(query, true, false, wrap)
    end, { desc = "Next " .. desc })
    vim.keymap.set({ "n", "x", "o" }, previous_start, function()
      if not allowed() then return end
      move_with_wrap(query, false, false, wrap)
    end, { desc = "Previous " .. desc })
  end
  -- Jumps to the next/previous node (by start position) captured as one of `captures` in the
  -- language's textobjects query, wrapping around at the ends. `accept` may drop nodes.
  local function move_through_captures(language, captures, forward, accept)
    -- get_parser returns nil (not an error) when the language has no parser.
    local ok, parser = pcall(vim.treesitter.get_parser, 0, language)
    if not ok or not parser then return end
    local query = vim.treesitter.query.get(language, "textobjects")
    if not query then return end

    local buffer = vim.api.nvim_get_current_buf()
    local tick = vim.api.nvim_buf_get_changedtick(buffer)
    local cache_key = language .. "\0" .. table.concat(captures, ",") .. "\0" .. (accept and "filtered" or "all")
    local cached = capture_cache[buffer] and capture_cache[buffer][cache_key]
    local targets
    if cached and cached.tick == tick then
      targets = cached.targets
    else
      local wanted = {}
      for _, name in ipairs(captures) do wanted[name] = true end
      targets = {}
      local seen = {}
      for capture_id, node in query:iter_captures(parser:parse()[1]:root(), 0, 0, -1) do
        if wanted[query.captures[capture_id]] and (not accept or accept(node)) then
          local start_row, start_column = node:start()
          local key = start_row .. ":" .. start_column
          if not seen[key] then
            seen[key] = true
            targets[#targets + 1] = { row = start_row, column = start_column }
          end
        end
      end
      table.sort(targets, function(left, right)
        return left.row < right.row or (left.row == right.row and left.column < right.column)
      end)
      capture_cache[buffer] = capture_cache[buffer] or {}
      capture_cache[buffer][cache_key] = { tick = tick, targets = targets }
    end
    if #targets == 0 then return end

    local cursor_row, cursor_column = unpack(vim.api.nvim_win_get_cursor(0))
    cursor_row = cursor_row - 1
    local target
    if forward then
      for _, candidate in ipairs(targets) do
        if candidate.row > cursor_row or (candidate.row == cursor_row and candidate.column > cursor_column) then
          target = candidate
          break
        end
      end
      target = target or targets[1]
    else
      for index = #targets, 1, -1 do
        local candidate = targets[index]
        if candidate.row < cursor_row or (candidate.row == cursor_row and candidate.column < cursor_column) then
          target = candidate
          break
        end
      end
      target = target or targets[#targets]
    end

    vim.cmd("normal! m'")
    if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end
    vim.api.nvim_win_set_cursor(0, { target.row + 1, target.column })
  end
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("NeoTextobjectsCache", { clear = true }),
    callback = function(event) capture_cache[event.buf] = nil end,
  })
  local function move_csharp_statement(forward)
    move_through_captures("c_sharp", { "statement.outer", "declaration.outer" }, forward, function(node)
      return node:type() ~= "block"
    end)
  end
  map_textobject("ab", "@block.outer", "Select around block")
  map_textobject("ib", "@block.contents", "Select block contents")
  map_textobject("af", "@function.outer", "Select around function")
  map_textobject("if", "@function.inner", "Select inside function")
  map_textobject("al", "@loop.outer", "Select around loop")
  map_textobject("il", "@loop.contents", "Select loop contents")
  map_textobject("aC", "@conditional.outer", "Select around conditional")
  map_textobject("iC", "@conditional.contents", "Select conditional contents")
  map_textobject("ac", "@class.outer", "Select around class")
  map_textobject("ic", "@class.inner", "Select inside class")
  map_textobject("aa", "@parameter.outer", "Select around parameter")
  map_textobject("ia", "@parameter.inner", "Select inside parameter")
  map_textobject("aq", "@query.outer", "Select around SQL query")
  map_textobject("aS", "@statement.outer", "Select around SQL statement")

  map_textobject_move("]f", "[f", "]F", "[F", "@function.outer", "function")
  map_textobject_start("]a", "[a", "@parameter.inner", "argument or parameter", true, true)
  map_textobject_move("]c", "[c", "]C", "[C", "@conditional.outer", "conditional")
  require("neo.textobjects.sql").setup({
    goto_range = goto_range,
    move_through_captures = move_through_captures,
    move_with_wrap = move_with_wrap,
    move_csharp_statement = move_csharp_statement,
  })
  map_textobject_start("]s", "[s", "@statement.outer", "SQL statement")
  map_textobject_start("]K", "[K", "@switch.case", "C# switch case")
end

return M
