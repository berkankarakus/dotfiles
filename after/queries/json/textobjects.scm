; extends

; Objects and arrays are blocks; the contents exclude the brackets.
[
  (object)
  (array)
] @block.outer

(object
  .
  "{"
  _* @block.contents
  "}")

(array
  .
  "["
  _* @block.contents
  "]")

; A pair, or an array element, is the JSON counterpart of a parameter. The outer range takes
; the following comma; the last element takes the preceding one instead, and a lone element
; has no comma at all. Each element matches exactly one of these, so the ranges never compete.
(object
  (pair) @parameter.inner @parameter.outer
  .
  "," @parameter.outer)

(object
  "," @parameter.outer
  .
  (pair) @parameter.inner @parameter.outer
  .)

(object
  .
  (pair) @parameter.inner @parameter.outer
  .)

(array
  (_) @parameter.inner @parameter.outer
  .
  "," @parameter.outer)

(array
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer
  .)

(array
  .
  (_) @parameter.inner @parameter.outer
  .)
