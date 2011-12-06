fs = require("fs")
view = require("http/mustache").view
ThreadBarrier = require("util/concurrent").ThreadBarrier
puts = require("util").debug
inspect = require("util").inspect
form = require("http/form").parser
certgen = require("security/certgen")
  
reportError = (response, error) ->
  response.writeHead 400
  response.write error
  response.end()
    
showCerts = (response, request) ->
  fs.readdir "certs", (err, files) ->
    fi = []
    puts files.length
    barrier = new ThreadBarrier files.length, () ->
      puts inspect fi
      view("showCerts", {certs:fi})(response, request)
    for f in files
      puts f
      do (f) -> 
        fs.stat "certs/#{f}", (err, stats) ->
          fi.push {name:"#{f}", size:stats.size}
          barrier.join()

notPresent = (formValues, required) ->
  for v in required
    unless formValues[v]
      return v
  return false

genCA = (response, request) ->
  form request, (formValues) ->
    try
      error = null
      if error = notPresent formValues, ["subject", "daysValidFor"]
        return reportError response, "You must supply a #{error}"
      puts formValues.subject
      puts formValues.daysValidFor
      certgen.genSelfSigned formValues.subject, formValues.daysValidFor, (err, key, cert)->
        puts "Came back"
        if err
          return reportError response, err
        response.writeHead 200, { 'Content-Type': 'application/json' }
        response.write JSON.stringify {key:key.toString(), cert:cert.toString()}
        response.end()

newCert = (response, request) ->
  form request, (formValues) ->
    if error = notPresent formValues, ["ca", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    caCert=caKey=""
    barrier = new ThreadBarrier 2, ->
      certgen.initSerialFile ->
        certgen.genKey (err, key) ->
          certgen.genCSR key.toString(), formValues.subject, (err, csr) ->
            certgen.signCSR csr.toString(), caCert, caKey, 1095, (err, finalCert) ->
              response.writeHead 200, { 'Content-Type': 'application/json' }
              response.write JSON.stringify {key:key.toString(), cert:finalCert.toString()}
              response.end()
    
    fs.readFile "certs/#{formValues.ca}.cert", (err, myCert) ->
      caCert = myCert.toString()
      barrier.join()
    fs.readFile "certs/#{formValues.ca}.key", (err, myKey) ->
      caKey = myKey.toString()
      barrier.join()

bundleCerts = (response, request) ->
  form request, (formValues) ->
    if error = notPresent formValues, ["bundlePath"]
      return reportError response, "You must supply a #{error}"
    bundlePath = formValues.bundlePath.split(" ")
    certs = new Array()  
    barrier = new ThreadBarrier bundlePath.length, ->
      response.writeHead 200, { 'Content-Type': 'application/json' }
      bundle = ""
      for x in certs
        bundle += x
      response.write JSON.stringify {bundle:bundle}
      response.end()
      
    for cert in [0..bundlePath.length-1]
      do (cert) ->
        fs.readFile "certs/#{bundlePath[cert]}.cert", (err, data) ->
          puts err if err
          certs[cert] = data.toString()
          barrier.join()
                   
newSigner = (response, request) ->
  form request, (formValues) ->
    if error = notPresent formValues, ["ca", "certName", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    caCert=caKey=""
    barrier = new ThreadBarrier 2, ->
      certgen.initSerialFile ->
        certgen.genKey (err, key) ->
          certgen.genCSR key.toString(), formValues.subject, (err, csr) ->
            certgen.signCSR csr.toString(), caCert, caKey, 1095, (err, finalCert) ->
              response.writeHead 200, { 'Content-Type': 'application/json' }
              barrier = new ThreadBarrier 2, ->
                response.write JSON.stringify {key:key.toString(), cert:finalCert.toString()}
                response.end()  
              fs.writeFile "certs/#{formValues.certName}.key", key, ->
                barrier.join()
              fs.writeFile "certs/#{formValues.certName}.cert", finalCert, ->
                barrier.join()      
    fs.readFile "certs/#{formValues.ca}.cert", (err, myCert) ->
      caCert = myCert.toString()
      barrier.join()
    fs.readFile "certs/#{formValues.ca}.key", (err, myKey) ->
      caKey = myKey.toString()
      barrier.join()

installCert = (response, request) ->
  form request, (parser) ->
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
      
exports.installCert = installCert
exports.showCerts = showCerts
exports.genCA = genCA
exports.newCert = newCert
exports.newSigner = newSigner
exports.bundleCerts = bundleCerts