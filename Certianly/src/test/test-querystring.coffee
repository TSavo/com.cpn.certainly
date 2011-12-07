TestSuite = require("util/test").TestSuite
parser = require("http/parameters").querystring

suite = new TestSuite 

suite.newTest "We can parse a query string", (assert) ->
  qs = 
    url:"http://test.com?qs1=val1&qs2=val2&qs3=val3"
  parser = parser(qs)
  assert.strictEqual parser("qs1"), "val1"  
  assert.strictEqual parser["qs2"], "val2"
  assert.strictEqual parser.qs3, "val3"
  expected = [
    {qs1:"val1"}
    {qs2:"val2"}
    {qs3:"val3"}
  ]
  actual = []
  for key, val of parser
    o = {}
    o[key] = val
    actual.push o
  assert.deepEqual expected, actual
suite.run()
