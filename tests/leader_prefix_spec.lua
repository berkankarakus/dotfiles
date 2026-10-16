-- A <leader> mapping that is also the prefix of another one makes Vim wait for 'timeoutlen'
-- before running the shorter one (:help map-ambiguous), so none of them may overlap.
local names = vim.tbl_keys(require("lazy.core.config").plugins)
require("lazy").load({ plugins = names })
for _, filetype in ipairs({ "cs", "sql" }) do
  vim.bo.filetype = filetype
  vim.api.nvim_exec_autocmds("FileType", { buffer = 0, modeline = false })
end
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })

local leader = vim.g.mapleader
local conflicts = {}
for _, mode in ipairs({ "n", "x", "i" }) do
  local lhs_list = {}
  for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
    if mapping.lhs:sub(1, #leader) == leader and #mapping.lhs > #leader then
      lhs_list[#lhs_list + 1] = mapping.lhs
    end
  end
  for _, short in ipairs(lhs_list) do
    for _, long in ipairs(lhs_list) do
      if #long > #short and long:sub(1, #short) == short then
        conflicts[#conflicts + 1] = string.format("[%s] %q is a prefix of %q", mode, short, long)
      end
    end
  end
end

assert(#conflicts == 0, "ambiguous leader mappings:\n" .. table.concat(conflicts, "\n"))
print("leader_prefix_spec: ok")
vim.cmd("qa!")
