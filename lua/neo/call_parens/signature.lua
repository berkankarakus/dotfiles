-- SignatureHelp parsing and completion placeholder planning for call_parens.
local M = {}

function M.request(buf, params, callback)
  vim.lsp.buf_request(buf, "textDocument/signatureHelp", params, function(err, result)
    callback(not err and result or nil)
  end)
end

local function takes_no_arguments(help)
  if not help or not help.signatures or #help.signatures == 0 then return false end
  for _, signature in ipairs(help.signatures) do
    if signature.parameters and #signature.parameters > 0 then return false end
  end
  return true
end

local LAMBDA_TYPES = {
  Func = function(count) return count - 1 end,
  Action = function(count) return count end,
  Predicate = function() return 1 end,
  Comparison = function() return 2 end,
  Converter = function() return 1 end,
}

local function split_top_level(text)
  local parts, depth, start = {}, 0, 1
  for index = 1, #text do
    local char = text:sub(index, index)
    if char == "<" or char == "(" or char == "[" then
      depth = depth + 1
    elseif char == ">" or char == ")" or char == "]" then
      depth = depth - 1
    elseif char == "," and depth == 0 then
      table.insert(parts, vim.trim(text:sub(start, index - 1)))
      start = index + 1
    end
  end
  local last = vim.trim(text:sub(start))
  if last ~= "" then table.insert(parts, last) end
  return parts
end

local function lambda_head(count)
  if count == 1 then return "x => " end
  if count == 0 then return "() => " end
  local names = {}
  for index = 1, count do names[index] = string.char(96 + index) end
  return "(" .. table.concat(names, ", ") .. ") => "
end

local function template_for(parameter_type)
  parameter_type = parameter_type:gsub("%?$", ""):gsub("^System%.", "")
  if parameter_type == "char" then return "''", 1 end
  local name, arguments = parameter_type:match("^([%w_]+)<(.*)>")
  name = name or parameter_type
  local parameter_count = LAMBDA_TYPES[name]
  if not parameter_count then return nil end
  local count = parameter_count(arguments and #split_top_level(arguments) or 0)
  if count < 0 then return nil end
  return lambda_head(count), 0
end

-- Roslyn labels a parameter with its name only; the type sits in the signature label.
local function parameter_declaration(signature, index, parameter)
  local text = (signature.label or ""):gsub("^%(extension%)%s*", "")
  local inside = text:match("%((.*)%)%s*$")
  local declaration = inside and split_top_level(inside)[index]
  if declaration then return declaration end
  local label = parameter.label
  if type(label) == "table" then label = signature.label and signature.label:sub(label[1] + 1, label[2]) end
  return type(label) == "string" and label or nil
end

local function parameter_type_of(label)
  label = label:gsub("%s*=.*$", "")
  local modifier = label:match("^%s*(%l+)%s")
  if modifier == "params" or modifier == "ref" or modifier == "out" or modifier == "in" or modifier == "this" then return nil end
  return label:match("^%s*(.-)%s+[%w_@]+%s*$")
end

local function argument_template(help)
  local agreed
  for _, signature in ipairs(help.signatures) do
    local first = signature.parameters and signature.parameters[1]
    if not first then return nil end
    local label = parameter_declaration(signature, 1, first)
    local parameter_type = label and parameter_type_of(label)
    if not parameter_type or (agreed and agreed ~= parameter_type) then return nil end
    agreed = parameter_type
  end
  if not agreed then return nil end
  return template_for(agreed)
end

function M.plan(help)
  if not help or not help.signatures or #help.signatures == 0 then return nil end
  local plan = { inside = "", back = 0, past_close = takes_no_arguments(help) }
  if not plan.past_close then
    local inside, back = argument_template(help)
    plan.inside, plan.back = inside or "", back or 0
  end
  return plan
end

return M
