local M = {}

local SEMICOLON_PARENTS = {
  expression_statement = true,
  local_declaration_statement = true,
  return_statement = true,
  throw_statement = true,
  break_statement = true,
  continue_statement = true,
  yield_statement = true,
  goto_statement = true,
  do_statement = true,
  field_declaration = true,
  event_field_declaration = true,
  using_directive = true,
  delegate_declaration = true,
}

local function last_token_on_row(node, row, best)
  local start_row, _, end_row = node:range()
  if row < start_row or row > end_row then return best end
  if node:child_count() == 0 then
    local token_row, token_column = node:end_()
    if token_row == row and node:type() ~= "comment" and not node:missing()
      and (not best or token_column > best.column) then
      return { type = node:type(), column = token_column }
    end
    return best
  end
  for child in node:iter_children() do best = last_token_on_row(child, row, best) end
  return best
end

local function count_errors(node)
  if node:type() == "ERROR" or node:missing() then return 1 end
  if not node:has_error() then return 0 end
  local total, explained = 0, false
  for child in node:iter_children() do
    if child:has_error() or child:type() == "ERROR" or child:missing() then
      explained = true
      total = total + count_errors(child)
    end
  end
  return explained and total or 1
end

local function has_error_on(node, row)
  local start_row, _, end_row = node:range()
  if row < start_row or row > end_row then return false end
  if node:type() == "ERROR" or node:missing() then return true end
  if not node:has_error() then return false end
  local explained = false
  for child in node:iter_children() do
    if child:has_error() or child:type() == "ERROR" or child:missing() then explained = true end
    if has_error_on(child, row) then return true end
  end
  return not explained
end

local EXPRESSION_BODIED = {
  property_declaration = true,
  method_declaration = true,
  indexer_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
}

local function ends_a_statement(parent)
  if SEMICOLON_PARENTS[parent:type()] then return true end
  if not EXPRESSION_BODIED[parent:type()] then return false end
  if #parent:field("value") > 0 then return true end
  for child in parent:iter_children() do
    if child:type() == "arrow_expression_clause" or child:type() == "equals_value_clause" then return true end
  end
  return false
end

local MEMBER_TYPES = {
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  accessor_declaration = true,
  local_function_statement = true,
  property_declaration = true,
  indexer_declaration = true,
  field_declaration = true,
  event_field_declaration = true,
  event_declaration = true,
  delegate_declaration = true,
}

local function member_node(root, row, column)
  local node = root:descendant_for_range(row, column, row, column)
  while node and not MEMBER_TYPES[node:type()] do node = node:parent() end
  return node
end

local TYPE_TYPES = {
  class_declaration = true,
  struct_declaration = true,
  record_declaration = true,
  record_struct_declaration = true,
  interface_declaration = true,
}

local function member_regions(member)
  local type_node = member:parent()
  while type_node and not TYPE_TYPES[type_node:type()] do type_node = type_node:parent() end
  local member_range = { member:range() }
  local body = type_node and type_node:field("body")[1]
  if not body or body:child_count() < 2 then return { member_range } end
  local open, close = body:child(0), body:child(body:child_count() - 1)
  if open:type() ~= "{" or close:type() ~= "}" then return { member_range } end
  local type_start_row, type_start_column = type_node:range()
  local open_end_row, open_end_column = open:end_()
  local close_start_row, close_start_column, close_end_row, close_end_column = close:range()
  return {
    { type_start_row, type_start_column, open_end_row, open_end_column },
    member_range,
    { close_start_row, close_start_column, close_end_row, close_end_column },
  }
end

local COMPACT_MEMBER_TYPES = {
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  property_declaration = true,
  indexer_declaration = true,
  field_declaration = true,
  event_field_declaration = true,
  event_declaration = true,
  delegate_declaration = true,
}

local function range_text(lines, start_row, start_column, end_row, end_column)
  if start_row == end_row then return lines[start_row + 1]:sub(start_column + 1, end_column) end
  local result = { lines[start_row + 1]:sub(start_column + 1) }
  for row = start_row + 1, end_row - 1 do result[#result + 1] = lines[row + 1] end
  result[#result + 1] = lines[end_row + 1]:sub(1, end_column)
  return table.concat(result, "\n")
end

local function compact_member_lines(lines, row, column, member)
  if not member or not COMPACT_MEMBER_TYPES[member:type()] then return end
  local regions = member_regions(member)
  local prefix_range, member_range, suffix_range = regions[1], regions[2], regions[3]
  if not suffix_range then return end
  local prefix = range_text(lines, prefix_range[1], prefix_range[2], prefix_range[3], prefix_range[4])
  local body = range_text(lines, member_range[1], member_range[2], member_range[3], member_range[4])
  local suffix = range_text(lines, suffix_range[1], suffix_range[2], suffix_range[3], suffix_range[4])
  local compact = prefix .. "\n" .. body .. "\n" .. suffix
  local compact_lines = vim.split(compact, "\n", { plain = true, trimempty = false })
  local prefix_lines = select(2, prefix:gsub("\n", "")) + 1
  local target_row = prefix_lines + row - member_range[1]
  local target_column = row == member_range[1] and column - member_range[2] or column
  if target_column < 0 then return end
  return compact_lines, target_row, target_column
end

local function insert_at(lines, row, column, text)
  local offset = column
  for index = 1, row do offset = offset + #lines[index] + 1 end
  local source = table.concat(lines, "\n")
  return source:sub(1, offset) .. text .. source:sub(offset + 1)
end

local function semicolon_fits(lines, row, column, member, errors_before, followed_by_else)
  local fits = false
  local parser
  pcall(function()
    local parse_lines, parse_row, parse_column = compact_member_lines(lines, row, column, member)
    local regions
    if not parse_lines then
      parse_lines, parse_row, parse_column = lines, row, column
      regions = member and member_regions(member) or nil
    end
    parser = vim.treesitter.get_string_parser(insert_at(parse_lines, parse_row, parse_column, ";"), "c_sharp")
    if regions then
      for _, region in ipairs(regions) do
        if region[1] == row and region[2] >= column then region[2] = region[2] + 1 end
        if region[3] == row and region[4] >= column then region[4] = region[4] + 1 end
      end
      parser:set_included_regions({ regions })
    end
    local root = parser:parse(true)[1]:root()
    local token = root:descendant_for_range(parse_row, parse_column, parse_row, parse_column + 1)
    local errors_after = count_errors(root)
    local errors_improved = errors_after < errors_before or followed_by_else and errors_after <= errors_before
    fits = not has_error_on(root, parse_row) and errors_improved
      and token ~= nil and token:type() == ";"
      and token:parent() ~= nil and ends_a_statement(token:parent())
  end)
  if parser then parser:destroy() end
  return fits
end

function M.finish_statement()
  local buf = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local closers = #line:sub(column + 1):match("^[%)%]]*")
  local semicolon = line:sub(column + closers + 1, column + closers + 1) == ";"
  local changed = closers > 0 or semicolon
  if changed then
    column = column + closers + (semicolon and 1 or 0)
    vim.api.nvim_win_set_cursor(0, { row, column })
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "c_sharp")
  if not ok or not parser then return changed end
  local root = parser:parse(true)[1]:root()
  local last = last_token_on_row(root, row - 1)
  if not last or last.type == ";" then return changed end
  local semicolon_column = last.column
  local member = member_node(root, row - 1, semicolon_column - 1)
  local next_line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local followed_by_else = next_line:match("^%s*else%f[%W]") ~= nil
  if not semicolon_fits(vim.api.nvim_buf_get_lines(buf, 0, -1, false), row - 1, semicolon_column, member,
    count_errors(member or root), followed_by_else) then
    return changed
  end

  vim.api.nvim_buf_set_text(buf, row - 1, semicolon_column, row - 1, semicolon_column, { ";" })
  vim.api.nvim_win_set_cursor(0, { row, math.max(column, semicolon_column + 1) })
  return true
end

return M
