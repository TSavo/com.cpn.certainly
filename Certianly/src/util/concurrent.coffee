class ThreadBarrier
  constructor: (@parties, @block) ->
    
  join: ->
    --@parties
    if @parties < 1
      @block()
    

class Semaphore
  constructor: ->
    @waiting = []
    @inUse = false

  acquire: (block) ->
    if @inUse
      @waiting.push block
    else
      @inUse = true
      setTimeout block, 0
      
  release: ->
    if @waiting.length > 0
      setTimeout @waiting.shift(), 0
    else
      @inUse = false
   
exports.ThreadBarrier = ThreadBarrier
exports.Semaphore = Semaphore
