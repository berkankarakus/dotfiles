local M = {}

M.source_globs = {
  "*.cs",
  "*.pas",
  "*.csproj",
  "*.sln",
  "*.slnx",
  "*.props",
  "*.targets",
  "*.json",
  "*.xml",
  "*.config",
  ".editorconfig",
}

function M.fuzzy_pattern(prompt)
  local characters = {}
  for _, character in ipairs(vim.fn.split(prompt, [[\zs]])) do
    if not character:match("%s") then
      characters[#characters + 1] = vim.fn.escape(character, [[\.^$|?*+()[]{}]])
    end
  end
  return table.concat(characters, ".*")
end

function M.fuzzy_grep_arguments(prompt)
  if not prompt or prompt == "" then return nil end

  local args = { "rg", "--vimgrep", "--ignore-case" }
  for _, glob in ipairs(M.source_globs) do args[#args + 1] = "--glob=" .. glob end
  args[#args + 1] = "--"
  args[#args + 1] = M.fuzzy_pattern(prompt)
  return args
end

return M
