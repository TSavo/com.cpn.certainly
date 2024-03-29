# Scope
# -----

# * Variable Safety
# * Variable Shadowing
# * Auto-closure (`do`)
# * Global Scope Leaks

test "reference `arguments` inside of functions", ->
  sumOfArgs = ->
    sum = (a,b) -> a + b
    sum = 0
    sum += num for num in arguments
    sum
  eq 10, sumOfArgs(0, 1, 2, 3, 4)

test "assignment to an Object.prototype-named variable should not leak to outer scope", ->
  # FIXME: fails on IE
  (->
    constructor = 'word'
  )()
  ok constructor isnt 'word'

test "siblings of splat parameters shouldn't leak to surrounding scope", ->
  x = 10
  oops = (x, args...) ->
  oops(20, 1, 2, 3)
  eq x, 10

test "catch statements should introduce their argument to scope", ->
  try throw ''
  catch e
    do -> e = 5
    eq 5, e
