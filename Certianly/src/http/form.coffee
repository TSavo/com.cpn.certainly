url = require('url') ;

exports.parser = (request, callback) ->
  body = ""
  if request.method is "POST" and request.headers["content-type"] is "application/x-www-form-urlencoded"
    request.on "data", (chunk) ->
      body += chunk

  request.on "end", ->
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
  