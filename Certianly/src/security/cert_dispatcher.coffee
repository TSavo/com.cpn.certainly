fs = require("fs")
view = require("http/mustache").view
ThreadBarrier = require("util/concurrent").ThreadBarrier
puts = require("util").debug
inspect = require("util").inspect
parameters = require("http/parameters").parameters
certgen = require("security/certgen")
  
reportError = (response, error) ->
  puts error
  response.writeHead 400
  response.write error
  response.end()

showCerts = (response, request) ->
  fs.readdir "certs", (err, files) ->
    fi = []
    puts files.length
    barrier = new ThreadBarrier files.length, () ->
      view("showCerts", {certs:fi})(response, request)
    for f in files
      do (f) -> 
        fs.stat "certs/#{f}", (err, stats) ->
          return reportError response, err if err
          fi.push {name:"#{f}", size:stats.size}
          barrier.join()

notPresent = (formValues, required) ->
  for v in required
    unless formValues[v]
      return v
  return false

genCA = (response, request) ->
  parameters request, (formValues) ->
    error = null
    if error = notPresent formValues, ["certName", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    certgen.genSelfSigned formValues.subject, formValues.daysValidFor, (err, key, cert)->
      return reportError response, err if err
      barrier = new ThreadBarrier 2, ->
        response.writeHead 200, { 'content-type': 'application/json' }
        response.write JSON.stringify {success:true}
        response.end()  
      fs.writeFile "certs/#{formValues.certName}.key", key, (err)->
        return reportError response, err if err
        barrier.join()
      fs.writeFile "certs/#{formValues.certName}.cert", cert, ->
        return reportError response, err if err
        barrier.join()

newCSR = (response, request) ->
  parameters request, (formValues) ->
    if error = notPresent formValues, ["certName", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    certgen.initSerialFile ->
      certgen.genKey (err, key) ->
        return reportError response, err if err
        certgen.genCSR key.toString(), formValues.subject, (err, csr) ->
          return reportError response, err if err
          fs.writeFile "certs/#{formValues.certName}.key", key, (err) ->
            return reportError response, err if err
            response.writeHead 200, { 'Content-Type': 'application/json' }
            response.write JSON.stringify {certName:formValues.certName, csr:csr.toString()}
            response.end()

signCSR = (response, request) ->
  parameters request, (formValues) ->
    caCert=caKey=""
    if error = notPresent formValues, ["csr", "ca"]
      return reportError response, "You must supply a #{error}"
    barrier = new ThreadBarrier 2, ->
      certgen.signCSR formValues.csr.toString(), caCert, caKey, 1095, (err, finalCert) ->
        return reportError response, err if err
        response.writeHead 200, { 'Content-Type': 'application/json' }
        response.write JSON.stringify {cert:finalCert.toString()}
        response.end()
    fs.readFile "certs/#{formValues.ca}.cert", (err, myCert) ->
      return reportError response, err if err
      caCert = myCert.toString()
      barrier.join()
    fs.readFile "certs/#{formValues.ca}.key", (err, myKey) ->
      return reportError response, err if err
      caKey = myKey.toString()
      barrier.join()


newCert = (response, request) ->
  parameters request, (formValues) ->
    if error = notPresent formValues, ["ca", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    caCert=caKey=""
    barrier = new ThreadBarrier 2, ->
      certgen.initSerialFile ->
        certgen.genKey (err, key) ->
          return reportError response, err if err
          certgen.genCSR key.toString(), formValues.subject, (err, csr) ->
            return reportError response, err if err
            certgen.signCSR csr.toString(), caCert, caKey, 1095, (err, finalCert) ->
              return reportError response, err if err
              response.writeHead 200, { 'Content-Type': 'application/json' }
              response.write JSON.stringify {key:key.toString(), cert:finalCert.toString()}
              response.end()
    
    fs.readFile "certs/#{formValues.ca}.cert", (err, myCert) ->
      return reportError response, err if err
      caCert = myCert.toString()
      barrier.join()
    fs.readFile "certs/#{formValues.ca}.key", (err, myKey) ->
      return reportError response, err if err
      caKey = myKey.toString()
      barrier.join()

bundleCerts = (response, request) ->
  parameters request, (formValues) ->
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
          return reportError response, err if err
          certs[cert] = data.toString()
          barrier.join()
                   
newSigner = (response, request) ->
  parameters request, (formValues) ->
    if error = notPresent formValues, ["ca", "certName", "subject", "daysValidFor"]
      return reportError response, "You must supply a #{error}"
    caCert=caKey=""
    barrier = new ThreadBarrier 2, ->
      certgen.initSerialFile ->
        certgen.genKey (err, key) ->
          return reportError response, err if err
          certgen.genCSR key.toString(), formValues.subject, (err, csr) ->
            return reportError response, err if err
            certgen.signCSR csr.toString(), caCert, caKey, 1095, (err, finalCert) ->
              return reportError response, err if err
              response.writeHead 200, { 'Content-Type': 'application/json' }
              barrier = new ThreadBarrier 2, ->
                response.write JSON.stringify {success:true}
                response.end()  
              fs.writeFile "certs/#{formValues.certName}.key", key, (err) ->
                return reportError response, err if err
                barrier.join()
              fs.writeFile "certs/#{formValues.certName}.cert", finalCert, (err) ->
                return reportError response, err if err
                barrier.join()      
    fs.readFile "certs/#{formValues.ca}.cert", (err, myCert) ->
      return reportError response, err if err
      caCert = myCert.toString()
      barrier.join()
    fs.readFile "certs/#{formValues.ca}.key", (err, myKey) ->
      return reportError response, err if err
      caKey = myKey.toString()
      barrier.join()

installCert = (response, request) ->
  parameters request, (parser) ->
    unless parser.certName
      return reportError response, "You must supply a name."
    unless parser.cert
      return reportError response, "You must supply a certificate"
      
    fs.writeFile "certs/#{parser.certName}.cert", parser.cert, (err) ->
      return reportError response, err if err
      response.writeHead 200, { 'content-type': 'application/json' }
      response.write JSON.stringify {success:true}
      response.end() 
    
exports.installCert = installCert
exports.showCerts = showCerts
exports.genCA = genCA
exports.newCert = newCert
exports.newSigner = newSigner
exports.bundleCerts = bundleCerts
exports.newCSR = newCSR
exports.signCSR = signCSR