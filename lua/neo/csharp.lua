local file_skeleton = require("neo.csharp.file_skeleton")
local docstring = require("neo.csharp.docstring")

local M = {}

function M.setup()
  file_skeleton.setup()
end

M.insert_docstring = docstring.insert
M.jump_docstring_field = docstring.jump_field

-- Kept as compatibility hooks for the existing C# parser tests.
M._split_parameters = docstring._split_parameters
M._parameter_name = docstring._parameter_name
M._find_parameter_list = docstring._find_parameter_list

return M
