url = require "url"

exports.parser = (request) ->
  urlObj = url.parse request.url, true
  result = (item) ->
    urlObj.query[item]
  for key, val of urlObj.query
    result[key] = val
  result