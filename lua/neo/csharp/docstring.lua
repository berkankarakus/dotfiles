local M = {}

-- Splits a parameter list on top-level commas only, so generics (`Dictionary<string, int>`),
-- tuples, attributes and string defaults (`"a,b"`) stay in one piece.
local function split_parameters(text)
  local parameters, depth, quote, start = {}, 0, nil, 1
  for index = 1, #text do
    local character = text:sub(index, index)
    if quote then
      if character == quote and text:sub(index - 1, index - 1) ~= "\\" then quote = nil end
    elseif character == '"' or character == "'" then
      quote = character
    elseif character:match("[<%(%[{]") then
      depth = depth + 1
    elseif character:match("[>%)%]}]") then
      depth = math.max(0, depth - 1)
    elseif character == "," and depth == 0 then
      parameters[#parameters + 1] = text:sub(start, index - 1)
      start = index + 1
    end
  end
  parameters[#parameters + 1] = text:sub(start)
  return parameters
end

-- The parameter name is the last identifier before a top-level `=` default value.
local function parameter_name(parameter)
  local depth, quote = 0, nil
  for index = 1, #parameter do
    local character = parameter:sub(index, index)
    if quote then
      if character == quote then quote = nil end
    elseif character == '"' or character == "'" then
      quote = character
    elseif character:match("[<%(%[{]") then
      depth = depth + 1
    elseif character:match("[>%)%]}]") then
      depth = math.max(0, depth - 1)
    elseif character == "=" and depth == 0 then
      parameter = parameter:sub(1, index - 1)
      break
    end
  end
  return parameter:match("([%a_][%w_]*)%s*$")
end

local MODIFIERS = {
  public = true, private = true, protected = true, internal = true, static = true, async = true,
  override = true, virtual = true, abstract = true, sealed = true, extern = true, unsafe = true,
  new = true, partial = true, readonly = true,
}

-- Returns the text inside the parameter list's parentheses and the text before them
-- (modifiers, return type, name). A tuple return type such as
-- `public (int, string) Pair(...)` has parentheses too, so a group counts only when it
-- follows an identifier that is not a modifier keyword (the method or type name).
local function find_parameter_list(signature)
  local position = 1
  while true do
    local open = signature:find("(", position, true)
    if not open then return nil end
    local group = signature:sub(open):match("^%b()")
    if not group then return nil end
    local head = signature:sub(1, open - 1):gsub("%s+$", "")
    -- `=` before the parentheses means an initializer or expression body, not a method.
    if head:find("=", 1, true) then return nil end
    local name = head:match("([%a_][%w_]*)$") or head:match("([%a_][%w_]*)%s*<.*>$")
    if name and not MODIFIERS[name] then return group:sub(2, -2), head end
    position = open + #group
  end
end

-- Return type = what is left of the head after dropping the method name (with generic
-- parameters) and leading modifiers. Constructors have none.
local function return_type_from_head(head)
  local before = head:gsub("[%a_][%w_]*%s*<.*>$", ""):gsub("[%a_][%w_]*$", "")
  while true do
    before = before:gsub("^%s+", "")
    local word = before:match("^([%a_][%w_]*)")
    if word and MODIFIERS[word] then before = before:sub(#word + 1) else break end
  end
  before = before:gsub("%s+$", "")
  if before == "" or before == "void" then return nil end
  return before
end

local function signature_from_buffer(bufnr, line_number, line_count, declaration)
  local signature = declaration
  for next_line = line_number + 1, math.min(line_number + 6, line_count) do
    -- Only keep reading while a parameter list is open; a class, property or field
    -- line has no "(" and must not borrow the next method's parameters.
    if not signature:find("(", 1, true) or find_parameter_list(signature) then break end
    signature = signature .. " " .. vim.api.nvim_buf_get_lines(bufnr, next_line - 1, next_line, false)[1]
  end
  return signature
end

local function docstring_lines(declaration, signature)
  local indent = declaration:match("^(%s*)") or ""
  local lines = { indent .. "/// <summary>", indent .. "/// ", indent .. "/// </summary>" }
  local parameters, head = find_parameter_list(signature)
  if parameters then
    for _, parameter in ipairs(split_parameters(parameters)) do
      local name = parameter_name(parameter)
      if name then lines[#lines + 1] = indent .. '/// <param name="' .. name .. '"></param>' end
    end
  end
  if head and return_type_from_head(head) then lines[#lines + 1] = indent .. "/// <returns></returns>" end
  return lines
end

local function fields_in_docstring(lines)
  local fields = {}
  local in_summary = false
  for offset, text in ipairs(lines) do
    if text:match("<summary>") then
      in_summary = true
    elseif text:match("</summary>") then
      in_summary = false
    elseif in_summary and text:match("^%s*///%s*$") then
      fields[#fields + 1] = { row = offset, column = #text }
    end

    local closing_tag = text:find("></param>", 1, true) or text:find("></returns>", 1, true)
    if closing_tag then fields[#fields + 1] = { row = offset, column = closing_tag } end
  end
  return fields
end

local function insert()
  if vim.bo.filetype ~= "cs" then
    vim.notify("Docstring shortcut is only available in C# files.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local declaration = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  while declaration:match("^%s*$") and line_number < vim.api.nvim_buf_line_count(bufnr) do
    line_number = line_number + 1
    declaration = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  end
  if declaration:match("^%s*$") then
    vim.notify("Place the cursor on a C# declaration or the blank line directly above it.", vim.log.levels.WARN)
    return
  end

  local previous_line = line_number - 1
  local previous = ""
  while previous_line > 0 do
    previous = vim.api.nvim_buf_get_lines(bufnr, previous_line - 1, previous_line, false)[1]
    if not previous:match("^%s*$") then break end
    previous_line = previous_line - 1
  end
  if previous:match("^%s*///") then
    vim.notify("This declaration already has a docstring.", vim.log.levels.INFO)
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local signature = signature_from_buffer(bufnr, line_number, line_count, declaration)
  local lines = docstring_lines(declaration, signature)

  vim.api.nvim_buf_set_lines(bufnr, line_number - 1, line_number - 1, false, lines)
  vim.api.nvim_win_set_cursor(0, { line_number + 1, #indent + 4 })
  vim.cmd("startinsert")
  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.keycode("<Right>"), "n", false)
  end)
end

local function jump_field()
  if vim.bo.filetype ~= "cs" then return false end

  local bufnr = vim.api.nvim_get_current_buf()
  local row, column = unpack(vim.api.nvim_win_get_cursor(0))
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_row, end_row = row, row
  local is_doc_line = function(line_number)
    local text = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
    return text:match("^%s*///") ~= nil
  end

  if not is_doc_line(row) then return false end
  while start_row > 1 and is_doc_line(start_row - 1) do start_row = start_row - 1 end
  while end_row < line_count and is_doc_line(end_row + 1) do end_row = end_row + 1 end

  local doc_lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local fields = fields_in_docstring(doc_lines)
  for _, field in ipairs(fields) do field.row = field.row + start_row - 1 end

  for _, field in ipairs(fields) do
    if field.row > row or (field.row == row and field.column > column) then
      vim.api.nvim_win_set_cursor(0, { field.row, field.column })
      return true
    end
  end

  for line_number = end_row + 1, math.min(end_row + 20, line_count) do
    local text = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
    if text:find("=>", 1, true) then return false end
    if text:find("{", 1, true) then
      local body_row = math.min(line_number + 1, line_count)
      local body = vim.api.nvim_buf_get_lines(bufnr, body_row - 1, body_row, false)[1]
      local first_character = body:find("%S")
      vim.api.nvim_win_set_cursor(0, { body_row, first_character and first_character - 1 or #body })
      return true
    end
  end
  return false
end

M.insert = insert
M.jump_field = jump_field
M._split_parameters = split_parameters
M._parameter_name = parameter_name
M._find_parameter_list = find_parameter_list

return M
