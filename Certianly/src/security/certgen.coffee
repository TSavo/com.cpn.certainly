exec = require("child_process").exec
spawn = require("child_process").spawn
fs = require("fs")
puts = require("util").debug
inspect = require("util").inspect
Semaphore = require("util/concurrent").Semaphore
ThreadBarrier = require("util/concurrent").ThreadBarrier

exclusive = new Semaphore
srlFile = "serial.srl"
 
 
randomString = (bits) ->
  chars = undefined
  rand = undefined
  i = undefined
  ret = undefined
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz012345678901"
  ret = ""
  while bits > 0
    rand = Math.floor(Math.random() * 0x100000000)
    i = 26
    while i > 0 and bits > 0
      ret += chars[0x3F & rand >>> i]
      i -= 6
      bits -= 6
  ret
  
randFile = ->
  randomString 512
  
###*
 * Construct an x509 -subj argument from an options object.
 * @param {Object} options An options object with optional email and hostname.
 * @return {String} A string suitable for use with x509 as a -subj argument.
###
buildSubj = (options) ->
  subject = ""
  for key, value of options
    if(key.length < 3)
      key = key.toUpperCase()
    if key in ["O", "OU", "L", "C", "ST", "CN", "emailAddress", "commonName", "state", "organization", "organizationalUnit", "country", "locality"]
      subject = "#{subject}/#{key}=#{value}"
  subject
  

genConfig = (options, callback) ->
  fs.readFile "config/openssl.cnf.template", (err, confTemplate) ->
    return callback(err) if err?
    confTemplate = confTemplate.toString().replace /%%SUBJECT_ALT_NAME%%/g, (if options.subjectAltName? then options.subjectAltName else "")
    confTemplate = confTemplate.toString().replace /%%NSCOMMENT%%/g, (if options.nsComment? then options.nsComment else "")
    confTemplate = confTemplate.toString().replace /%%BASIC_CONSTRAINTS%%/g, (if options.CA? and options.CA then "CA:TRUE" else "CA:FALSE")
    confTemplate = confTemplate.toString().replace /CA:TRUE/g, (if options.pathlen? and options.pathlen > -1 then "CA:TRUE,pathlen:#{options.pathlen}" else "CA:TRUE")
    confFile = "config/#{randFile()}"
    fs.writeFile confFile, confTemplate, (err) ->
      return callback(err) if err?
      callback null, confFile

genExtensions = (options, callback) ->
  puts inspect options
  confTemplate = "basicConstraints=critical,CA:#{options.CA}"
  if options.CA and options.pathlen? and options.pathlen > -1
    confTemplate += ",pathlen:#{options.pathlen}"
  confTemplate += "\n"
  confTemplate += "subjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nkeyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment, keyAgreement"
  if options.CA
    confTemplate += ", keyCertSign, cRLSign"
  confTemplate += "\n"
  if not options.CA
    confTemplate += "extendedKeyUsage=critical,serverAuth,clientAuth,codeSigning,emailProtection,timeStamping\n"
  for k, v of options
    if(k in ["subjectAltName", "nsComment"])
      confTemplate += "#{k}=#{v}\n"
  confFile = "config/#{randFile()}"
  fs.writeFile confFile, confTemplate, (err) ->
    return callback(err) if err?
    callback null, confFile
    
findExtensions = (csr, callback) ->
  verifyCSR csr, (err, text) ->
    return callback(err) if err?
    text = text.toString()
    text = text.split("\n")
    result = {}
    for item, i in text
      if text[i].indexOf("X509v3 Subject Alternative Name:") > -1
        result.subjectAltName = text[i+1].trim()
      if text[i].indexOf("Netscape Comment:") > -1
        result.nsComment = text[i+1].trim()
      if text[i].indexOf("X509v3 Basic Constraints:") > -1
        puts text[i+1]
        result.CA = text[i+1].trim().toUpperCase().indexOf("CA:TRUE") > -1
        match = text[i+1].trim().match(/.*pathlen:(\d+)/)
        result.pathlen = match[1] if match? and match.length > 1
    callback null, result
###*
 * Generates a Self signed X509 Certificate.
 *
 * @param {String} outputKey Path to write the private key to.
 * @param {String} outputCert Path to write the certificate to.
 * @param {Object} options An options object with optional email and hostname.
 * @param {Function} callback fired with (err).
###
genSelfSigned = (options, daysValidFor, callback) ->
  keyFile = "temp/#{randFile()}"
  certFile = "temp/#{randFile()}"
  subjectAltName = null
  optionString = options
  if typeof options == "object"
    optionString = buildSubj options
  reqArgs = [ "-batch", "-x509", "-nodes", "-days #{daysValidFor}", "-subj \"#{optionString}\"", "-sha1", "-newkey rsa:2048", "-keyout #{keyFile}", "-out #{certFile}" ]    
  return genConfig options, (err, confFile) ->
    return callback(err) if err?
    reqArgs.push "-config #{confFile}"
    return selfSign reqArgs, certFile, keyFile, confFile, callback


selfSign = (reqArgs, certFile, keyFile, confFile, callback) ->
  cmd = "openssl req " + reqArgs.join(" ")
  exec cmd, (err, stdout, stderr) ->
    fs.unlink confFile if confFile?
    if err
      fs.unlink certFile
      fs.unlink keyFile
      return callback err
    key=cert=""
    ThreadBarrier b = new ThreadBarrier 2, ->
      callback null, key, cert
    fs.readFile certFile, (certErr, myCert) ->
      fs.unlink certFile
      cert = myCert
      b.join()  
    fs.readFile keyFile, (keyErr, myKey) ->
      fs.unlink keyFile
      key = myKey
      b.join()        
    
###*
 * Generate an RSA key.
 *
 * @param {String} outputKey Location to output the key to.
 * @param {Function} callback Callback fired with (err).
###
genKey = (callback) ->
  keyFile = "temp/#{randFile()}"
  args = [ "-out #{keyFile}", 2048 ]
  cmd = "openssl genrsa " + args.join(" ")
  exec cmd, (err, stdout, stderr) ->
    if err
      fs.unlink keyFile
      return callback err        
    fs.readFile keyFile, (err, key) ->
      fs.unlink keyFile
      if err 
        return callback err
      callback null, key



###*
 * Generate a CSR for the specified key, and pass it back as a string through
 * a callback.
 * @param {String} inputKey File to read the key from.
 * @param {String} outputCSR File to store the CSR to.
 * @param {Object} options An options object with optional email and hostname.
 * @param {Function} callback Callback fired with (err, csrText).
###
genCSR = (key, options, callback) ->
  keyFile = "temp/#{randFile()}"
  CSRFile = "temp/#{randFile()}"
  subjectAltName = null
  subject = options
  if typeof options == "object"
    subject = buildSubj options
  args = [ "-batch", "-new", "-nodes", "-subj \"#{subject}\"", "-key #{keyFile}", "-out #{CSRFile}" ]
  fs.writeFile keyFile, key, (err) ->
    return callback err if err?
    return genConfig options, (err, confFile) ->
      return callback(err) if err?
      args.push "-config #{confFile}"
      CSR args, keyFile, CSRFile, confFile, callback
    
CSR = (args, keyFile, CSRFile, confFile, callback) ->      
  cmd = "openssl req " + args.join(" ")
  exec cmd, (err, stdout, stderr) ->
    ###fs.unlink confFile if confFile?###
    return callback "Error while executing: #{cmd}\n#{err}" if err?
    fs.unlink keyFile        
    fs.readFile CSRFile, (err, csr) ->
      return callback err if err?
      fs.unlink CSRFile
      callback null, csr
        

       
###*
 * Initialize an openssl '.srl' file for serial number tracking.
 * @param {String} srlPath Path to use for the srl file.
 * @param {Function} callback Callback fired with (err).
###
initSerialFile = (callback) ->
  fs.writeFile srlFile, "00", callback

###*
 * Verify a CSR.
 * @param {String} csrPath Path to the CSR file.
 * @param {Function} callback Callback fired with (err).
###
verifyCSR = (csr, callback) ->
  CSRFile = "temp/#{randFile()}"
  args = [ "-verify", "-noout", "-in #{CSRFile} -text" ]
  cmd = "openssl req #{args.join(" ")}"
  fs.writeFile CSRFile, csr, ->
    exec cmd, (err, stdout, stderr) ->
      fs.unlink CSRFile
      callback err, stdout, stderr 
###*
 * Sign a CSR and store the resulting certificate to the specified location
 * @param {String} csrPath Path to the CSR file.
 * @param {String} caCertPath Path to the CA certificate.
 * @param {String} caKeyPath Path to the CA key.
 * @param {String} caSerialPath Path to the CA serial number file.
 * @param {String} outputCert Path at which to store the certificate.
 * @param {Function} callback Callback fired with (err).
###
signCSR = (csr, caCert, caKey, daysValidFor, callback) ->
  csrPath = "temp/#{randFile()}"
  certPath = "temp/#{randFile()}"
  keyPath = "temp/#{randFile()}"
  outputPath = "temp/#{randFile()}"
  barrier = new ThreadBarrier 3, ->
    findExtensions csr, (err, extensions) ->
      puts inspect extensions
      genExtensions extensions, (err, extensionFile) ->
        args = [ "-req", "-days #{daysValidFor}", "-CA \"#{certPath}\"", "-CAkey \"#{keyPath}\"", "-CAserial \"#{srlFile}\"", "-in #{csrPath}", "-out #{outputPath}", "-extfile #{extensionFile}" ]
        
        cmd = "openssl x509 #{args.join(" ")}"
        exec cmd, (err, stdout, stderr) ->
          fs.unlink keyPath
          fs.unlink csrPath
          fs.unlink certPath
          fs.unlink extensionFile
          if err?
            return callback "Error while executing: #{cmd}\n#{err}"
          fs.readFile outputPath, (err, output) ->
            fs.unlink outputPath
            return callback(err) if err?
            return callback null, output

  fs.writeFile csrPath, csr, (err) ->
    barrier.join()
  fs.writeFile certPath, caCert, (err) ->
    barrier.join()
  fs.writeFile keyPath, caKey, (err) ->
    barrier.join()    

###*
 * Retrieve a SHA1 fingerprint of a certificate.
 * @param {String} certPath Path to the certificate.
 * @param {Function} callback Callback fired with (err, fingerprint).
###
getCertFingerprint = (cert, callback) ->
  certPath = "temp/#{randFile()}"
  fs.writeFile certPath, cert, (err) ->
    if(err)
      return callback err
    args = [ "-noout", "-in \"#{certPath}\"", "-fingerprint", "-sha1" ]
    cmd = "openssl x509 #{args.join(" ")}"
    exec cmd, (err, stdout, stderr) ->
      fs.unlink certPath
      if err
        callback err, stdout, stderr if callback?
        return
      segments = stdout.split("=")
      if segments.length isnt 2 or segments[0] isnt "SHA1 Fingerprint"
        callback new Error("Unexpected output from openssl"), stdout, stderr
        return
      callback null, (segments[1] || '').replace(/^\s+|\s+$/g, '') if callback?

sign = (key, message, callback) ->
  keyPath = "temp/#{randFile()}"
  messagePath = "temp/#{randFile()}"
  sigPath = "temp/#{randFile()}"
  barrier = new ThreadBarrier 2, ->
    args = ["-sign #{keyPath}", "-out #{sigPath}"]
    cmd = "openssl dgst -sha1 #{args.join(" ")} #{messagePath}"
    exec cmd, (err, stdout, stderr) ->
      fs.unlink keyPath
      fs.unlink messagePath
      if(err)
        return callback err, stdout, stderr
      fs.readFile sigPath, (err, sig) ->
        fs.unlink sigPath
        callback err, sig
      
  fs.writeFile keyPath, key, (err) ->
    barrier.join()
  fs.writeFile messagePath, message, (err) ->
    barrier.join()
            
verify = (cert, sig, message, callback) ->
  certPath = "temp/#{randFile()}"
  messagePath = "temp/#{randFile()}"
  sigPath = "temp/#{randFile()}"
  barrier = new ThreadBarrier 3, ->
    args = ["-prverify #{certPath}", "-signature #{sigPath}"]
    cmd = "openssl dgst -sha1 #{args.join(" ")} #{messagePath}"
    exec cmd, (err, stdout, stderr) ->
      fs.unlink certPath
      fs.unlink messagePath
      fs.unlink sigPath
      callback err, stdout, stderr
    
  fs.writeFile certPath, cert, (err) ->
    barrier.join()
  fs.writeFile messagePath, message, (err) ->
    barrier.join()    
  fs.writeFile sigPath, sig, (err) ->
    barrier.join()
    
bundle = (certNames, callback) ->
  certs = new Array()  
  barrier = new ThreadBarrier certNames.length, ->
    bundle = ""
    for x in certs
      bundle += x
    callback null, bundle
  error = false
  for cert in [0..certNames.length-1]
    do (cert) ->
      fs.readFile "certs/#{certNames[cert]}.cert", (err, data) ->
        if err?
          return if error
          error = true
          return callback err
        certs[cert] = data.toString()
        barrier.join()

pcs12 = (inCert, callback) ->
  certFile = "temp/#{randFile()}"
  pkcsFile = "temp/#{randFile()}"
  args = [ "-export", "-nokeys", "-in \"#{certFile}\"", "-passout pass:", "-out \"#{pkcsFile}\"" ]
  cmd = "openssl pkcs12 #{args.join(" ")}"
  fs.writeFile certFile, inCert, (err) ->
    return callback(err) if err?
    exec cmd, (err, stdout, stderr) ->
      fs.unlink certFile
      return callback(err) if err?
      fs.readFile pkcsFile, (err, pkcs) ->
        return callback(err) if err?
        fs.unlink pkcsFile
        callback null, pkcs  
  
pkcs12 = (inKey, inCert, callback) ->
  keyFile = "temp/#{randFile()}"
  certFile = "temp/#{randFile()}"
  pkcsFile = "temp/#{randFile()}"
  args = [ "-export", "-inkey \"#{keyFile}\"", "-in \"#{certFile}\"", "-passout pass:", "-out \"#{pkcsFile}\"" ]
  cmd = "openssl pkcs12 #{args.join(" ")}"
  barrier = new ThreadBarrier 2, ->
    exec cmd, (err, stdout, stderr) ->
      fs.unlink keyFile
      fs.unlink certFile
      return callback(err) if err?
      fs.readFile pkcsFile, (err, pkcs) ->
        return callback(err) if err?
        fs.unlink pkcsFile
        callback null, pkcs  
  fs.writeFile keyFile, inKey, (err) ->
    return callback(err) if err?
    barrier.join()
  fs.writeFile certFile, inCert, (err) ->
    return callback(err) if err?
    barrier.join() 

exports.genSelfSigned = genSelfSigned
exports.genKey = genKey
exports.genCSR = genCSR
exports.initSerialFile = initSerialFile
exports.verifyCSR = verifyCSR
exports.signCSR = signCSR
exports.getCertFingerprint = getCertFingerprint
exports.sign = sign
exports.verify = verify
exports.bundle = bundle
exports.pkcs12 = pkcs12
exports.pcs12 = pcs12