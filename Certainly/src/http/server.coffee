http = require("http")
url = require("url")
puts = require("util").debug

start = (route, handle) ->
  onRequest = (request, response) ->
    pathname = url.parse(request.url).pathname
    route handle, pathname, response, request
  server = http.createServer(onRequest).listen 8888
  puts "Server has started."
  server

exports.start = start