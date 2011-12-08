assert = require("assert")
puts = require("util").debug
print = require("util").debug
fs = require("fs")
inspect = require("util").inspect
ThreadBarrier = require("util/concurrent").ThreadBarrier

class TestCase
  constructor: (@name, @block) ->
    @assert = new SafeAssert
    @hasBeenRun = false
    
  run: (suite) ->
    @block(@assert)
    if @hasBeenRun
      return puts "WARNING!!!! Test cases should not be run more than once! Skipping the next test case in our suite... (Offending test case: #{@name})"

    @hasBeenRun = true
    suite.done(this)
    
class AsyncTestCase extends TestCase
  
  run: (@suite) ->
    @block(@assert, this)
  
  done: ->
    if @hasBeenRun
      return puts "WARNING!!!! Test cases should not be run more than once! Skipping the next test case in our suite... (Offending test case: #{@name})"
    @hasBeenRun = true
    @suite.done(this)
  
global.badExitHandler = ->
  puts inspect(global.badExit)
    
class TestSuite
  
  
  constructor: ->
    @tests = []
    @testCounter = 0
    for test in arguments
      @tests.push(test)
    @barrier = null
    global.badExit = {}
    
  addTest: (test) ->
    @tests.push(test)
    return this
  
  newTest: (name, block) ->
    @addTest new TestCase(name, block)
    return this
    
  newAsyncTest: (name, block) ->
    @addTest new AsyncTestCase(name, block)
    return this
  
  

  run: ->
    process.on 'exit', global.badExitHandler
    process.on 'unhandledException', global.badExitHandler
    self = this
    @barrier = new ThreadBarrier @tests.length, () ->
      self.finish()
    @before() if @before
    for test in @tests
      do (test) ->
        setTimeout(->
          test.run self
        ,0)
      
  done: (test) ->
    delete global.badExit[test.name]
    @barrier.join()

  finish: ->
    @report()
    process.removeListener "exit", global.badExitHandler
    process.removeListener "unhandledException", global.badExitHandler
    @after() if @after
    
  
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
        me.fail err if err
        me.fail("We were expecting the file '#{file}' to be of non-zero length but it wasn't.") if stat.size == 0
        ++me.succeeded
      catch e
        me.failures.push e
      finally
        callback() if callback


  fileAbsent : (file, callback) ->
    me = this
    fs.stat file, (err, stat) ->
      try
        if(!err)
          me.fail("File #{file} exists but it shouldn't.")
          return
        ++me.succeeded 
      finally
        callback() if callback
  
  isError : (value, message) ->
    if assert.ifError(value)
      @fail(message)
    else
      ++@succeeded
      
  isNotError : (value, message) ->
    if value
      @fail(message)
    else
      ++@succeeded
  
exports.SafeAssert = SafeAssert
exports.TestCase = TestCase
exports.AsyncTestCase = AsyncTestCase
exports.TestSuite = TestSuite 
