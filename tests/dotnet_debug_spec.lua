vim.opt.rtp:prepend(vim.fn.getcwd())

local debug = require("neo.dotnet_debug")

local function assert_equal(expected, actual, message)
  if expected ~= actual then error((message or "values differ") .. string.format(" (expected %s, got %s)", vim.inspect(expected), vim.inspect(actual)), 0) end
end

local resolves = 0
local cache = debug.launch_context_cache(function()
  resolves = resolves + 1
  return { project_file = "App.csproj", program = "App.dll" }
end)

assert_equal("App.dll", cache.get().program, "first lookup should resolve the launch context")
assert_equal("App.csproj", cache.get().project_file, "subsequent lookup should reuse the launch context")
assert_equal(1, resolves, "launch context should be resolved once per debug session")

cache.reset()
cache.get()
assert_equal(2, resolves, "a new debug session should resolve a fresh launch context")

local nil_resolves = 0
local nil_cache = debug.launch_context_cache(function()
  nil_resolves = nil_resolves + 1
  return nil
end)
assert_equal(nil, nil_cache.get(), "nil launch contexts should be supported")
assert_equal(nil, nil_cache.get(), "nil launch contexts should be cached too")
assert_equal(1, nil_resolves, "nil launch context should not trigger repeated resolution")

print("dotnet_debug_spec: ok")
