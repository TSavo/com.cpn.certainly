Semaphore = require("util/concurrent").Semaphore
ThreadBarrier = require("util/concurrent").ThreadBarrier
puts = require("util").puts
AsyncTestCase = require("util/test").AsyncTestCase
TestSuite = require("util/test").TestSuite

suite = new TestSuite
suite.newAsyncTest "We can use a Semaphore to serialize operations", (assert, test) ->
  s = new Semaphore
  arr = []
  s.acquire ->
    arr.push "once"
    s.release()
  
  s.acquire ->
    arr.push "twice"
    s.release()
    
  s.acquire ->
    arr.push "three times a lady"
    s.release()
    assert.deepEqual ["once", "twice", "three times a lady"], arr
    test.done()

suite.newAsyncTest "We can use a ThreadBarrier to ensure that multiple threads join up at a common point", (assert, test) ->
  counter = 0
  t = new ThreadBarrier 5, ->
    assert.equal(counter, 5)
    test.done()
  for i in [1..5]
    setTimeout -> 
      ++counter
      t.join()
    , 0

suite.run()


