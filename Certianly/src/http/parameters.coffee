url = require('url')
puts = require("util").debug
inspect = require("util").inspect

parameters = (request, callback = ->) ->
  query = querystring request
  form request, (data) ->
    if typeof data is "object"
      for key, val of data
        query[key] = val
    callback query if callback?

form = (request, callback = ->) ->
  body = ""
  request.on "data", (chunk) ->
    body += chunk

  request.on "end", ->
    if request.headers["content-type"] is "application/x-www-form-urlencoded"
      params = body.split("&")
      o = {}
      for param of params
        pair = params[param].split("=")
        o[pair[0]] = unescape pair[1].replace /\+/g, " "
      callback o if callback?
    else if request.headers["content-type"] is "application/json"
      callback JSON.parse body if callback?
    else
      callback "ERROR: unknown content type: #{request["content-type"]}" if callback?

querystring= (request) ->
  urlObj = url.parse request.url, true
  result = {}
  for key, val of urlObj.query
    result[key] = val
  result
  
exports.querystring = querystring
exports.form = form
exports.parameters = parameters