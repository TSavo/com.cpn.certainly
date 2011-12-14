exec = require("child_process").exec
fs = require("fs")
puts = require("util").puts
Semaphore = require("util/concurrent").Semaphore
ThreadBarrier = require("util/concurrent").ThreadBarrier

exclusive = new Semaphore
srlFile = "serial.srl"
 
 
randomString = (bits) ->
  chars = undefined
  rand = undefined
  i = undefined
  ret = undefined
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#!"
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
    subject = "#{subject}/#{key}=#{value}"
  subject
  
###*
 * Generates a Self signed X509 Certificate.
 *
 * @param {String} outputKey Path to write the private key to.
 * @param {String} outputCert Path to write the certificate to.
 * @param {Object} options An options object with optional email and hostname.
 * @param {Function} callback fired with (err).
###
genSelfSigned = (options, daysValidFor, callback) ->
  keyFile = randFile()
  certFile = randFile()
  if typeof options == "object"
    options = buildSubj options
  reqArgs = [ "-batch", "-x509", "-nodes", "-days #{daysValidFor}", "-subj \"#{options}\"", "-sha1", "-newkey rsa:2048", "-keyout #{keyFile}", "-out #{certFile}" ]    
  cmd = "openssl req " + reqArgs.join(" ")
  exec cmd, (err, stdout, stderr) ->
    if err
      fs.unlink certFile
      fs.unlink keyFile
      callback err
      return
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
  keyFile = randFile()
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
  keyFile = randFile()
  CSRFile = randFile()
  if typeof options == "object"
    options = buildSubj options
  args = [ "-batch", "-new", "-nodes", "-subj \"#{options}\"", "-key #{keyFile}", "-out #{CSRFile}" ]
  cmd = "openssl req " + args.join(" ")
  fs.writeFile keyFile, key, ->
    return callback err if err
    exec cmd, (err, stdout, stderr) ->
      return callback "Error while executing: #{cmd}\n#{err}" if err
      fs.unlink keyFile        
      fs.readFile CSRFile, (err, csr) ->
        return err if err
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
  CSRFile = randFile()
  args = [ "-verify", "-noout", "-in #{CSRFile}" ]
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
  csrPath = randFile()
  certPath = randFile()
  keyPath = randFile()
  outputPath = randFile()
  barrier = new ThreadBarrier 3, ->
    args = [ "-req", "-days #{daysValidFor}", "-CA \"#{certPath}\"", "-CAkey \"#{keyPath}\"", "-CAserial \"#{srlFile}\"", "-in #{csrPath}", "-out #{outputPath}" ]
    cmd = "openssl x509 #{args.join(" ")}"
    exec cmd, (err, stdout, stderr) ->
      fs.unlink keyPath
      fs.unlink csrPath
      fs.unlink certPath
      if err
        return callback "Error while executing: #{cmd}\n#{err}"
      fs.readFile outputPath, (err, output) ->
        fs.unlink outputPath
        if err
          return callback err
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
  certPath = randFile()
  fs.writeFile certPath, cert, (err) ->
    if(err)
      return callback err
    args = [ "-noout", "-in \"#{certPath}\"", "-fingerprint", "-sha1" ]
    cmd = "openssl x509 #{args.join(" ")}"
    exec cmd, (err, stdout, stderr) ->
      fs.unlink certPath
      if err
        callback err, stdout, stderr
        return
      segments = stdout.split("=")
      if segments.length isnt 2 or segments[0] isnt "SHA1 Fingerprint"
        callback new Error("Unexpected output from openssl"), stdout, stderr
        return
      callback null, (segments[1] || '').replace(/^\s+|\s+$/g, '')

sign = (key, message, callback) ->
  keyPath = randFile()
  messagePath = randFile()
  sigPath = randFile()
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
  certPath = randFile()
  messagePath = randFile()
  sigPath = randFile()
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
    
exports.genSelfSigned = genSelfSigned
exports.genKey = genKey
exports.genCSR = genCSR
exports.initSerialFile = initSerialFile
exports.verifyCSR = verifyCSR
exports.signCSR = signCSR
exports.getCertFingerprint = getCertFingerprint
exports.sign = sign
exports.verify = verify