local M = {}

-- `swe`: a switch expression whose arms grow with Tab. Tab on a typed result adds another arm;
-- Tab on an arm's untouched pattern (or on an untouched result) takes the arm away or moves on
-- to the `_ =>` default. The arms are a recursive choice node, so removing one is just
-- cycling the choice back, which leaves no stray text.
function M.switch_expression(ls)
  local s, t, i, sn, c, d = ls.snippet, ls.text_node, ls.insert_node, ls.snippet_node, ls.choice_node, ls.dynamic_node

  local more_arms
  more_arms = function()
    return sn(nil, {
      c(1, {
        t(""),
        sn(nil, {
          t({ "", "    " }), i(1, "pattern", { key = "swe_pattern" }), t(" => "), i(2, "result", { key = "swe_result" }),
          t(","), d(3, more_arms, {}),
        }),
      }),
    })
  end

  return s("swe", {
    i(1, "value"), t({ " switch", "{", "    " }), i(2, "pattern", { key = "swe_pattern" }), t(" => "),
    i(3, "result", { key = "swe_result" }), t(","), d(4, more_arms, {}),
    t({ "", "    _ => " }), i(5, "default"), t({ ",", "}" }), i(0),
  })
end

local function text_of(node)
  return table.concat(node:get_text(), "\n")
end

-- Tab inside a `swe` snippet. Returns true when it handled the key.
function M.switch_tab()
  local ls = require("luasnip")
  local node = ls.session.current_nodes[vim.api.nvim_get_current_buf()]
  if not node or not node.key then return false end
  local root = node.parent and node.parent.snippet
  if not root or root.trigger ~= "swe" then return false end

  if node.key == "swe_result" then
    ls.jump(1) -- onto the arms choice node
    if text_of(node) ~= "result" then
      ls.change_choice(1) -- which grows by one arm and lands in its pattern
    else
      ls.jump(1) -- nothing typed: on to the default
    end
    return true
  end

  if node.key == "swe_pattern" and text_of(node) == "pattern" and ls.session.active_choice_nodes[vim.api.nvim_get_current_buf()] then
    ls.change_choice(1) -- an arm that was never filled in goes away again
    ls.jump(1)
    return true
  end
  return false
end

return M
