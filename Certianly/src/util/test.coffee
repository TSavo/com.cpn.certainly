assert = require("assert")
puts = require("util").puts
print = require("util").print
fs = require("fs")

class TestCase
  constructor: (@name, @block) ->
    @assert = new SafeAssert

  run: (suite) ->
    @block(@assert)
    suite.next()
    
class AsyncTestCase extends TestCase
  
  run: (@suite) ->
    @block(@assert, this)
  
  done: ->
    @suite.next()
    
class TestSuite
  
  constructor: ->
    @tests = []
    @testCounter = 0
    for test in arguments
      @tests.push(test)
    @me = this
  
  addTest: (test) ->
    @tests.push(test)
    return @me
  
  newTest: (name, block) ->
    @addTest new TestCase(name, block)
    return @me
    
  newAsyncTest: (name, block) ->
    @addTest new AsyncTestCase(name, block)
    return @me
  
  reportBadExit: ->
    puts global.badExitString
   
  run: ->
    me = this
    global.badExitString = "ERROR: Exited before we could run the tests" 
    process.on 'exit', @reportBadExit
    @beforeSuite() if @beforeSuite
    @_next()
  
  next: ->
    if @tests[@testCounter - 1].assert.failures.length == 0
      print "."
    else
      print "F"
    @after() if @after
    @_next()
    
  _next: ->
    if @testCounter == @tests.length
      puts ""
      @report()
      @afterSuite() if @afterSuite
      process.removeListener "exit", @reportBadExit
      return
    @before() if @before
    global.badExitString = "ERROR: TestCase '#{@tests[@testCounter].name}' did not finish!" 
    @tests[@testCounter++].run(this)
  
  report: ->
    passed = 0
    failed = 0
    for test in @tests
      if test.assert.failures.length == 0
        result = "PASSED"
        ++passed
      else
        result = "FAILED"
        ++failed
      puts "#{test.name} #{result} [#{test.assert.succeeded} / #{test.assert.failures.length + test.assert.succeeded}]"
      for failure in test.assert.failures
        puts "  Error: #{failure}"
    result = "FAILED"
    if failed == 0
      result = "PASSED"
    puts "Suite Results: #{result} Tests Run: #{passed + failed} Passed: #{passed} Failed: #{failed}"
    
class SafeAssert
  
  constructor: ->
    @failures = []
    @succeeded = 0
    @name = "SafeAssert"
    
  fail : (actual, expected, message, operator, stackStartFunction) ->
    @failures.push(new assert.AssertionError({
      actual:actual,
      expected:expected,
      message:message,
      operator:operator,
      stackStartFunction
    }))  
  
  ok : (value, message) ->
    try
      assert.ok(value, message)
      ++@succeeded
    catch e
      @failures.push(e)
  
  isTrue : (value, message) ->
    @ok value, message
    
  equal : (actual, expected, message) ->
    try
      assert.equal actual, expected, message 
      ++@succeeded
    catch e
      @failures.push e

  notEqual : (actual, expected, message) ->
    try
      assert.notEqual actual, expected, message
      ++@succeeded
    catch e
      @failures.push e

  deepEqual : (actual, expected, message) ->
    try
      assert.deepEqual actual, expected, message
      ++@succeeded
    catch e
      @failures.push e
      
  notDeepEqual : (actual, expected, message) ->
    try
      assert.notDeepEqual actual, expected, message
      ++@succeeded
    catch e
      @failures.push e

  isNull : (actual, message) ->
    try
      assert.equal actual, null, message
      ++@succeeded
    catch e
      @failures.push e
  
  isNotNull : (actual, message) ->
    try
      assert.notEqual actual, null, message
      ++@succeeded
    catch e
      @failures.push e
    
  strictEqual : (actual, expected, message) ->
    try
      assert.strictEqual actual, expected, message
      ++@succeeded
    catch e
      @failures.push e

  notStrictEqual : (actual, expected, message) ->
    try
      assert.notStrictEqual actual, expected, message
      ++@succeeded
    catch e
      @failures.push e
      
  throws : (block, error, message) ->
    try
      assert.throws block, error, message
      ++@succeeded
    catch e
      @failures.push e
      
  doesNotThrow : (block, error, message) ->
    try
      assert.doesNotThrow block, error, message
      ++@succeeded
    catch e
      @failures.push e
     
  fileExists : (file, callback) ->
    me = this
    fs.stat file, (err, stat) ->
      try
        if(err)
          me.fail err
        try
          me.isTrue stat.size > 0, "We were expecting the file '#{file}' to be of non-zero length but it wasn't."
        catch e
          me.failures.push e
      finally
        callback() if callback


  fileAbsent : (file, callback) ->
    me = this
    fs.stat file, (err, stat) ->
      if(!err)
        me.fail("File #{file} exists but it shouldn't.") 
      me.succeeded = me.succeeded + 1 
      callback() if callback
  
  isError : (value, message) ->
    if assert.ifError(value)
      @fail(message)
    else
      ++@succeeded
      
  isNotError : (value, message) ->
    if !assert.ifError(value)
      @fail(message)
    else
      ++@succeeded
  
exports.SafeAssert = SafeAssert
exports.TestCase = TestCase
exports.AsyncTestCase = AsyncTestCase
exports.TestSuite = TestSuite 
