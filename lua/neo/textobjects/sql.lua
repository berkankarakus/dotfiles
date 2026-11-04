local M = {}

-- SQL and JSON use the same public motions, but their syntax-tree traversal is intentionally
-- isolated from the generic selection and C# statement movement in neo.textobjects.
function M.setup(ctx)
  local function is_json()
    return vim.treesitter.language.get_lang(vim.bo.filetype) == "json"
  end

  -- JSON counterparts: a pair or array element plays the role of a clause (]k), an object or
  -- array the role of a query. ]r and [r are exact mirrors, in document order and wrapping at the
  -- ends (the SQL [r climbs to the parent query instead, which in JSON would only ever reach the root).
  local function map_sql_clause(next_start, previous_start)
    local function move_clause(forward)
      if vim.bo.filetype == "cs" or vim.bo.filetype == "c_sharp" then
        ctx.move_csharp_statement(forward)
        return
      end
      if is_json() then
        ctx.move_through_captures("json", { "parameter.inner" }, forward)
        return
      end
      local ok, parser = pcall(vim.treesitter.get_parser, 0)
      if not ok or not parser then return end
      local row, column = unpack(vim.api.nvim_win_get_cursor(0))
      row = row - 1
      local node = parser:parse()[1]:root():named_descendant_for_range(row, column, row, column)
      local clause_types, scope_node, query_specification
      while node do
        if node:type() == "query_specification" then
          query_specification = node
          scope_node = node
          clause_types = { select = true, from = true, where = true, group_by = true, having = true }
          break
        elseif node:type() == "statement" then
          for child in node:iter_children() do
            if child:type() == "query_specification" then
              query_specification = child
              scope_node = child
              clause_types = { select = true, from = true, where = true, group_by = true, having = true }
              break
            end
          end
          if query_specification then break end
          node = node:parent()
        elseif node:type() == "update" then
          scope_node = node
          clause_types = { keyword_update = true, keyword_set = true, from = true, where = true }
          break
        elseif node:type() == "delete" then
          scope_node = node
          clause_types = { keyword_delete = true, from = true, where = true }
          break
        else
          node = node:parent()
        end
      end
      if not scope_node then return end

      local clauses = {}
      for child in scope_node:iter_children() do
        if clause_types[child:type()] then clauses[#clauses + 1] = child end
        if child:type() == "from" then
          for from_child in child:iter_children() do
            if from_child:type() == "join" then clauses[#clauses + 1] = from_child end
          end
        end
      end
      if query_specification then
        local statement = query_specification:parent()
        if statement and statement:type() == "statement" then
          for child in statement:iter_children() do
            local child_type = child:type()
            if child_type == "order_by" or child_type == "offset_fetch" then
              clauses[#clauses + 1] = child
            end
          end
        end
        table.sort(clauses, function(left, right)
          local left_row, left_column = left:range()
          local right_row, right_column = right:range()
          return left_row < right_row or (left_row == right_row and left_column < right_column)
        end)
      end
      if #clauses == 0 then return end

      local target
      if forward then
        for _, clause in ipairs(clauses) do
          local clause_row, clause_column = clause:range()
          if clause_row > row or (clause_row == row and clause_column > column) then
            target = clause
            break
          end
        end
        target = target or clauses[1]
      else
        for index = #clauses, 1, -1 do
          local clause_row, clause_column = clauses[index]:range()
          if clause_row < row or (clause_row == row and clause_column < column) then
            target = clauses[index]
            break
          end
        end
        target = target or clauses[#clauses]
      end

      vim.cmd("normal! m'")
      if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end
      local target_row, target_column = target:range()
      vim.api.nvim_win_set_cursor(0, { target_row + 1, target_column })
    end
    vim.keymap.set({ "n", "x", "o" }, next_start, function()
      move_clause(true)
    end, { desc = "Next SQL clause, C# statement or JSON item" })
    vim.keymap.set({ "n", "x", "o" }, previous_start, function()
      move_clause(false)
    end, { desc = "Previous SQL clause, C# statement or JSON item" })
  end

  local function map_sql_query(next_start, previous_start)
    local function go_to_parent_scope()
      local ok, parser = pcall(vim.treesitter.get_parser, 0)
      if not ok or not parser then return false end
      local row, column = unpack(vim.api.nvim_win_get_cursor(0))
      local node = parser:parse()[1]:root():named_descendant_for_range(row - 1, column, row - 1, column)
      while node and node:type() ~= "query_specification" do
        node = node:parent()
      end
      if not node then return false end

      node = node:parent()
      while node do
        local node_type = node:type()
        if node_type == "query_specification" or node_type == "update" or node_type == "delete" then
          local target_row, target_column = node:range()
          ctx.goto_range({ target_row, target_column, 0, target_row, target_column, 0 }, false)
          return true
        end
        node = node:parent()
      end
      return false
    end
    vim.keymap.set({ "n", "x", "o" }, next_start, function()
      if is_json() then
        ctx.move_through_captures("json", { "block.outer" }, true)
        return
      end
      ctx.move_with_wrap("@query.outer", true, false)
    end, { desc = "Next SQL query or JSON block" })
    vim.keymap.set({ "n", "x", "o" }, previous_start, function()
      if is_json() then
        ctx.move_through_captures("json", { "block.outer" }, false)
        return
      end
      if not go_to_parent_scope() then ctx.move_with_wrap("@query.outer", false, false) end
    end, { desc = "Parent SQL query or statement, previous JSON block" })
  end

  map_sql_query("]r", "[r")
  map_sql_clause("]k", "[k")
end

return M
