local M = {}

-- SQL and JSON use the same public motions, but their syntax-tree traversal is intentionally
-- isolated from the generic selection and C# statement movement in neo.textobjects.

local QUERY_CLAUSES = { select = true, from = true, where = true, group_by = true, having = true }
local UPDATE_CLAUSES = { keyword_update = true, keyword_set = true, from = true, where = true }
local DELETE_CLAUSES = { keyword_delete = true, from = true, where = true }

local function is_json()
  return vim.treesitter.language.get_lang(vim.bo.filetype) == "json"
end

local function current_parser()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  return ok and parser or nil
end

local function cursor_node(parser)
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  return parser:parse()[1]:root():named_descendant_for_range(row, column, row, column), row, column
end

local function query_scope(node)
  while node do
    local node_type = node:type()
    if node_type == "query_specification" then
      return node, node, QUERY_CLAUSES
    elseif node_type == "statement" then
      for child in node:iter_children() do
        if child:type() == "query_specification" then return child, child, QUERY_CLAUSES end
      end
    elseif node_type == "update" then
      return node, nil, UPDATE_CLAUSES
    elseif node_type == "delete" then
      return node, nil, DELETE_CLAUSES
    end
    node = node:parent()
  end
end

local function append_join_clauses(clauses, node)
  if node:type() ~= "from" then return end
  for child in node:iter_children() do
    if child:type() == "join" then clauses[#clauses + 1] = child end
  end
end

local function sort_by_position(nodes)
  table.sort(nodes, function(left, right)
    local left_row, left_column = left:range()
    local right_row, right_column = right:range()
    return left_row < right_row or (left_row == right_row and left_column < right_column)
  end)
end

local function collect_clauses(scope_node, query_specification, clause_types)
  local clauses = {}
  for child in scope_node:iter_children() do
    if clause_types[child:type()] then clauses[#clauses + 1] = child end
    append_join_clauses(clauses, child)
  end

  if query_specification then
    local statement = query_specification:parent()
    if statement and statement:type() == "statement" then
      for child in statement:iter_children() do
        local child_type = child:type()
        if child_type == "order_by" or child_type == "offset_fetch" then clauses[#clauses + 1] = child end
      end
    end
    sort_by_position(clauses)
  end
  return clauses
end

local function next_node(nodes, row, column, forward)
  if forward then
    for _, node in ipairs(nodes) do
      local node_row, node_column = node:range()
      if node_row > row or (node_row == row and node_column > column) then return node end
    end
    return nodes[1]
  end

  for index = #nodes, 1, -1 do
    local node_row, node_column = nodes[index]:range()
    if node_row < row or (node_row == row and node_column < column) then return nodes[index] end
  end
  return nodes[#nodes]
end

local function move_to_clause(node)
  vim.cmd("normal! m'")
  if vim.api.nvim_get_mode().mode == "no" then vim.cmd("normal! v") end
  local row, column = node:range()
  vim.api.nvim_win_set_cursor(0, { row + 1, column })
end

local function move_clause(ctx, forward)
  if vim.bo.filetype == "cs" or vim.bo.filetype == "c_sharp" then
    ctx.move_csharp_statement(forward)
    return
  end
  if is_json() then
    ctx.move_through_captures("json", { "parameter.inner" }, forward)
    return
  end

  local parser = current_parser()
  if not parser then return end
  local node, row, column = cursor_node(parser)
  local scope_node, query_specification, clause_types = query_scope(node)
  if not scope_node then return end

  local clauses = collect_clauses(scope_node, query_specification, clause_types)
  if #clauses == 0 then return end
  move_to_clause(next_node(clauses, row, column, forward))
end

local function parent_query_scope(ctx)
  local parser = current_parser()
  if not parser then return false end
  local node = cursor_node(parser)
  while node and node:type() ~= "query_specification" do node = node:parent() end
  if not node then return false end

  node = node:parent()
  while node do
    local node_type = node:type()
    if node_type == "query_specification" or node_type == "update" or node_type == "delete" then
      local row, column = node:range()
      ctx.goto_range({ row, column, 0, row, column, 0 }, false)
      return true
    end
    node = node:parent()
  end
  return false
end

local function map_sql_clause(ctx, next_start, previous_start)
  vim.keymap.set({ "n", "x", "o" }, next_start, function()
    move_clause(ctx, true)
  end, { desc = "Next SQL clause, C# statement or JSON item" })
  vim.keymap.set({ "n", "x", "o" }, previous_start, function()
    move_clause(ctx, false)
  end, { desc = "Previous SQL clause, C# statement or JSON item" })
end

local function map_sql_query(ctx, next_start, previous_start)
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
    if not parent_query_scope(ctx) then ctx.move_with_wrap("@query.outer", false, false) end
  end, { desc = "Parent SQL query or statement, previous JSON block" })
end

function M.setup(ctx)
  map_sql_query(ctx, "]r", "[r")
  map_sql_clause(ctx, "]k", "[k")
end

return M
