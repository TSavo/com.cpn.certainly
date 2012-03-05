server = require("http/server")
router = require("http/router")

class Application
  constructor: (@pages = {}) ->
  
  addPage: (name, page) ->
    @pages[name] = page
    this

  start: ->
    @server = server.start router.route, @pages
    
  stop: ->
    @server.close() if @server
    
exports.Application = Application