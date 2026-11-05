-- This helper is loaded by the lazy Telescope config rather than init.lua, so load it directly in
-- the headless unit test before the lazy cache has seen the new module.
local search = dofile("lua/neo/telescope_search.lua")

assert(search.fuzzy_pattern("Pa rse") == "P.*a.*r.*s.*e", "fuzzy pattern should ignore spaces")
assert(search.fuzzy_pattern("a+b") == "a.*\\+.*b", "regex metacharacters must be escaped")
assert(search.fuzzy_grep_arguments("") == nil, "empty prompts should not start rg")

local args = search.fuzzy_grep_arguments("Parse")
assert(args[1] == "rg" and args[2] == "--vimgrep" and args[3] == "--ignore-case", "rg flags should be stable")
assert(args[#args] == "P.*a.*r.*s.*e", "the fuzzy pattern should be the final argument")
assert(vim.tbl_contains(args, "--glob=*.cs"), "C# sources should be searched")
assert(vim.tbl_contains(args, "--glob=*.sql") == false, "unrelated files should not be searched")

print("telescope_search_spec: ok")
vim.cmd("qa!")
