TestSuite = require("util/test").TestSuite
mustache = require("http/mustache").to_html
partial = require("http/mustache").partial
puts = require("util").debug
suite = new TestSuite 

view = 
  title: "Joe",
  calc: ->
    2 + 4

template = "{{title}} spends {{calc}}"

suite.newTest "We can render a template", (assert) ->
  mustache template, view, null, (html) ->
    assert.equal html, "Joe spends 6"
    
suite.newAsyncTest "We can render a partial", (assert, test) ->
  partial "test", view, null, (err, html) ->
    assert.isNotError err
    assert.equal html, "Joe spends 6"
    test.done()
    
suite.run()
