puts = require("util").debug
inspect = require("util").inspect
parameters = require("http/parameters").parameters

route = (handle, pathname, response, request) ->
  if handle[pathname] and typeof handle[pathname][request.method] is "function"
    parameters request, (formValues) ->
      handle[pathname][request.method] request, response, formValues
  else
    puts "No request handler found for " + pathname
    response.writeHead 404,
      "Content-Type": "text/html"

    response.write "404 Not found"
    response.end()
    

exports.route = route