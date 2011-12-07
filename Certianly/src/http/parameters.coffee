url = require('url') ;

parameters = (request, callback) ->
  query = querystring request
  form request, (data) ->
    if typeof data is "object"
      for key, val of data
        query[key] = val
    callback query

form = (request, callback) ->
  body = ""
  if request.method in ["POST", "PUT", "DELETE"] and request.headers["content-type"] in ["application/x-www-form-urlencoded", "application/json"]
    request.on "data", (chunk) ->
      body += chunk

  request.on "end", ->
    if request["content-type"] is "application/x-www-form-urlencoded"
      params = body.split("&")
      o = {}
      for param of params
        pair = params[param].split("=")
        o[pair[0]] = unescape pair[1].replace /\+/g, " "
      result = (item) ->
        o[item]
      for key, val of o
        result[key] = val
      callback result    
    else if request["content-type"] is "application/json"
      callback JSON.parse body
    else
      puts "ERROR: unknown content type: #{request["content-type"]}"
      callback "ERROR: unknown content type: #{request["content-type"]}"

querystring= (request) ->
  urlObj = url.parse request.url, true
  result = (item) ->
    result[item]
  for key, val of urlObj.query
    result[key] = val
  result
  
exports.querystring = querystring
exports.form = form
exports.parameters = parameters