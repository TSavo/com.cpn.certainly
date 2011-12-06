puts = require("util").debug
inspect = require("util").inspect

route = (handle, pathname, response, request) ->
  console.log "About to route a request for " + pathname
  if handle[pathname] and typeof handle[pathname][request.method] is "function"
    handle[pathname][request.method] response, request
  else
    console.log "No request handler found for " + pathname
    response.writeHead 404,
      "Content-Type": "text/html"

    response.write "404 Not found"
    response.end()
    

exports.route = route