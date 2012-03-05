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
  response.write error.toString()
  response.end()

showCerts = (request, response, parameters) ->
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

jsonResponse = (response, entity) ->
  response.writeHead 200, { 'content-type': 'application/json' }
  response.write JSON.stringify entity
  response.end()
genCA = (request, response, formValues) ->
  error = null
  if error = notPresent formValues, ["subject", "daysValidFor"]
    return reportError response, "You must supply a #{error}"
  subject = formValues.subject
  certgen.genSelfSigned subject, formValues.daysValidFor, (err, key, cert)->
    return reportError response, err if err?
    formValues.privateKey = key.toString()
    formValues.cert = cert.toString()
    formValues.selfSigned = true
    delete subject.id
    jsonResponse response, formValues

genKey = (request, response, formValues) ->
  certgen.genKey (err, privateKey) ->
    return reportError(response, err) if err?
    formValues.privateKey = privateKey.toString()
    jsonResponse response, formValues

newCSR = (request, response, formValues) ->
  if error = notPresent formValues, ["subject","privateKey"]
    return reportError response, "You must supply a #{error}"
  certgen.genCSR formValues.privateKey, formValues.subject, (err, csr) ->
    return reportError response, err if err?
    result = 
      signee:
        formValues            
      csr:csr.toString()
    jsonResponse response, result

signCSR = (request, response, formValues) ->
  caCert=caKey=""
  if error = notPresent formValues, ["csr", "signer", "signee"]
    return reportError response, "You must supply a #{error}"
  certgen.signCSR formValues.csr, formValues.signer.cert, formValues.signer.privateKey, formValues.signee.daysValidFor, (err, finalCert) ->
    return reportError response, err if err?
    formValues.signee.cert = finalCert.toString()
    formValues.signee.signer = formValues.signer
    jsonResponse response, formValues.signee
    
genCABundle = (certificate) ->
  ca = certificate.cert;
  if certificate.signer
    ca += genCABundle certificate.signer
  ca
    
pkcs12 = (request, response, formValues) ->
  unless formValues.certificate? and formValues.caBundle?
    return reportError response, "You must supply a certificate and caBundle."
  ca = formValues.caBundle
  certificate = formValues.certificate;
  puts ca
  if certificate.privateKey?
    certgen.pkcs12 certificate.privateKey, certificate.cert, ca, certificate.subject.CN, (err, pkcs)->
      return reportError response, err if err?
      formValues.certificate.pkcs12 = pkcs.toString("base64")
      jsonResponse response, formValues.certificate    
  else
    certgen.pcs12 certificate.cert, ca, certificate.subject.CN, (err, pkcs)->
      return reportError response, err if err?
      formValues.certificate.pkcs12 = pkcs.toString("base64")
      jsonResponse response, formValues.certificate
     
     
sign = (request, response, formValues) ->
  if error = notPresent formValues, ["cert", "privateKey", "ca", "message"]
    return reporterror response, "You must supply a #{error}"
  certgen.sign formValues.cert, formValues.privateKey, formValues.ca, new Buffer(formValues.message, "base64"), (error, results) ->
    puts results.toString("base64")
    jsonResponse response, {result:results.toString("base64")}
  

       
exports.genCA = genCA
exports.genKey = genKey
exports.newCSR = newCSR
exports.signCSR = signCSR
exports.pkcs12 = pkcs12
exports.sign = sign