certgen = require "security/certgen"
qs = require("http/querystring").parser
form = require("http/form").parser
puts = require("util").debug
inspect = require("util").inspect

start = (response) ->
  console.log "Request handler 'start' was called."
  body = "<html>" + "<head>" + "<meta http-equiv=\"Content-Type\" " + "content=\"text/html; charset=UTF-8\" />" + "</head>" + "<body>" + "
  <form action=\"/installCert\" method=\"post\">
  <textarea type=\"textarea\" name=\"certname\" ></textarea>
  <textarea type=\"textarea\" name=\"cert\" ></textarea>
  <textarea type=\"textarea\" name=\"key\" ></textarea>
  <input type=\"submit\" value=\"Upload file\" />
  </form>" + "</body>" + "</html>"
  response.writeHead 200,
    "Content-Type": "text/html"

  response.write body
  response.end()

selfSignTest = (response, request) ->
  details = qs(request)
  certgen.genSelfSigned {"commonName":qs.commonName, "organizationalUnitName":qs.organizationalUnitName, "organizationName":qs.organizationName}, 1095, (err, key, cert) ->
    result =
      key:key.toString(), 
      cert:cert.toString()
    response.writeHead 200, 
      "Content-Type": "application/json"
    response.write JSON.stringify(result)
    response.end()

reportError = (response, error) ->
  response.writeHead 400
  response.write error
  
installCert = (response, request) ->
  details = form request, (parser) ->
    try
      puts inspect parser
      unless parser.certname
        return reportError response, "You must supply a name."
      unless parser.cert
        return reportError response, "You must supply a certificate"
      unless parser.key
        return reportError response, "You must supply a key"
        
      fs.writeFile "certs/#{parser.certname}.cert", parser.cert, (err) ->
        puts err
      fs.writeFile "certs/#{parser.certname}.key", parser.key, (err) ->
        puts err
      response.writeHead 200
      response.write "Successfully installed #{parser.certname}"
    catch e
      response.write "Failed: #{e}"
    finally
      response.end() 
    
show = (response) ->
  console.log "Request handler 'show' was called."
  fs.readFile "/tmp/test.png", "binary", (error, file) ->
    if error
      response.writeHead 500,
        "Content-Type": "text/plain"

      response.write error + "\n"
      response.end()
    else
      response.writeHead 200,
        "Content-Type": "image/png"

      response.write file, "binary"
      response.end()
querystring = require("querystring")
fs = require("fs")

exports.start = start
exports.selfSignTest = selfSignTest
exports.show = show
exports.installCert = installCert