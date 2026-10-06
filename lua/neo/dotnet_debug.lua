local M = {}

function M.launch_context_cache(resolve)
  local resolved = false
  local value

  return {
    get = function()
      if not resolved then
        value = resolve()
        resolved = true
      end
      return value
    end,
    reset = function()
      resolved = false
      value = nil
    end,
  }
end

return M
