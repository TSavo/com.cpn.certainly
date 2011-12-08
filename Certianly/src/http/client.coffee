http = require("http")

class HttpClient
  constructor: (@host, @port) ->
  get:(path, callback)->
    http.get(
      host:@host
      port:@port
      path:path
    , (result) ->
      body = ""
      result.on "data", (chunk) ->
        body += chunk
      result.on "end", ->
        if result.headers["content-type"] is "application/json"
          body = JSON.parse body
        callback body
    )
  
  post:(path, data, callback) ->
    this.send path, data, "POST", callback
  put:(path, data, callback) ->
    this.send path, data, "PUT", callback
  delete:(path, data, callback) ->
    this.send path, data, "DELETE", callback
  
  send:(path, data, method, callback)->
    request = http.request(
      host:@host
      port:@port
      path:path
      method:method
      headers:
        "content-type":"application/json"
    , (result) ->
      body = ""
      result.on "data", (chunk) ->
        body += chunk
      result.on "end", ->
        if result.headers["content-type"] is "application/json"
          body = JSON.parse body
        callback body
    )
    request.write JSON.stringify data if data
    request.end()
exports.HttpClient = HttpClient
