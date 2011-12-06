server = require("http/server")
router = require("http/router")

class Application
  constructor: (@pages = {}) ->
  
  addPage: (name, page) ->
    @pages[name] = page
    this

  start: ->
    server.start router.route, @pages
    
exports.Application = Application