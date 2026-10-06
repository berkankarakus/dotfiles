; extends

; Stored procedures, functions, and triggers share the function text object.
[
  (create_procedure)
  (alter_procedure)
  (create_function)
  (alter_function)
  (create_trigger)
  (alter_trigger)
] @function.outer

; Select a procedure body when it is not wrapped in BEGIN/END.
(procedure_body (statement) @function.inner)

; BEGIN/END is the T-SQL equivalent of a block. The inner variants omit them.
(block) @block.outer
(block . (keyword_begin) . _* @block.contents (keyword_end))

; The inner function selection excludes BEGIN/END when a body has a block.
[
  (procedure_body
    (block . (keyword_begin) . _* @function.inner (keyword_end)))
  (function_body
    (block . (keyword_begin) . _* @function.inner (keyword_end)))
]

(while_statement) @loop.outer
(while_statement
  body: (block . (keyword_begin) . _* @loop.contents (keyword_end)))

(if_statement) @conditional.outer
[
  (if_statement
    consequence: (block . (keyword_begin) . _* @conditional.contents (keyword_end)))
  (if_statement consequence: (statement) @conditional.contents)
]

(function_argument) @parameter.outer
(function_argument) @parameter.inner

(query_specification) @query.outer
(statement) @statement.outer
