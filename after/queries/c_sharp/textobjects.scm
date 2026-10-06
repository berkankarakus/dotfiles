; extends

; C# block bodies without their surrounding braces.
(block
  .
  "{"
  _* @block.contents
  "}")

; Loop bodies without their surrounding braces.
(for_statement
  body: (block
    .
    "{"
    _* @loop.contents
    "}"))

(foreach_statement
  body: (block
    .
    "{"
    _* @loop.contents
    "}"))

(do_statement
  (block
    .
    "{"
    _* @loop.contents
    "}"))

(while_statement
  (block
    .
    "{"
    _* @loop.contents
    "}"))

; Conditional bodies without their surrounding braces.
(if_statement
  consequence: (block
    .
    "{"
    _* @conditional.contents
    "}"))

(if_statement
  alternative: (block
    .
    "{"
    _* @conditional.contents
    "}"))

(switch_statement
  body: (switch_body
    .
    "{"
    _* @conditional.contents
    "}"))

; Move linearly between case/default branches in a switch statement.
(switch_section) @switch.case
