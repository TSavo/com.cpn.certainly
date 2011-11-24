exec = require("child_process").exec
fs = require("fs")
puts = require("util").puts
Semaphore = require("util/concurrent").Semaphore

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
  reqArgs = [ "-batch", "-x509", "-nodes", "-days #{daysValidFor}", "-subj \"#{buildSubj(options)}\"", "-sha1", "-newkey rsa:2048", "-keyout #{keyFile}", "-out #{certFile}" ]
  cmd = "openssl req " + reqArgs.join(" ")
  exec cmd, (err, stdout, stderr) ->
    if err
      fs.unlink certFile, ->
        fs.unlink keyFile, ->
          callback err
      return
    fs.readFile certFile, (certErr, cert) ->
      fs.unlink certFile, ->
        fs.readFile keyFile, (keyErr, key) ->
          fs.unlink keyFile, ->
            if certErr
              return callback certErr
            if keyErr
              return callback keyErr
            callback null, key, cert
    
    
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
      fs.unlink keyFile, ->
        return callback err
    fs.readFile keyFile, (err, key) ->
      if err 
        return callback err
      fs.unlink keyFile, ->
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
  args = [ "-batch", "-new", "-nodes", "-subj \"#{buildSubj(options)}\"", "-key #{keyFile}", "-out #{CSRFile}" ]
  cmd = "openssl req " + args.join(" ")
  fs.writeFile keyFile, key, ->
    exec cmd, (err, stdout, stderr) ->
      fs.unlink keyFile, ->
        if err
          fs.unlink CSRFile, ->
            return callback err
        fs.readFile CSRFile, (err, csr) ->
          if err
            fs.unlink CSRFile, ->
              return callback err
          fs.unlink CSRFile, (err) ->
            if err
              return callback err
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
      fs.unlink CSRFile, ->
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
  fs.writeFile csrPath, csr, (err) ->
    if err
      fs.unlink csrPath
      return callback err
    fs.writeFile certPath, caCert, (err) ->
      if err
        fs.unlink certPath
        fs.unlink csrPath
        return callback err
      fs.writeFile keyPath, caKey, ->
        if err
          fs.unlink keyPath
          fs.unlink csrPath
          fs.unlink certPath
          return callback err
        args = [ "-req", "-days #{daysValidFor}", "-CA \"#{certPath}\"", "-CAkey \"#{keyPath}\"", "-CAserial \"#{srlFile}\"", "-in #{csrPath}", "-out #{outputPath}" ]
        cmd = "openssl x509 #{args.join(" ")}"
        exec cmd, (err, stdout, stderr) ->
          fs.unlink keyPath
          fs.unlink csrPath
          fs.unlink certPath
          if err
            return callback err
          fs.readFile outputPath, (err, output) ->
            if err
              return callback err
            fs.unlink outputPath
            return callback null, output


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
  fs.writeFile keyPath, key, (err) ->
    if err
      fs.unlink keyPath
      return callback err
    fs.writeFile messagePath, message, (err) ->
      if err
        fs.unlink keyPath
        fs.unlink messagePath
        return callback err
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
          
verify = (cert, sig, message, callback) ->
  certPath = randFile()
  messagePath = randFile()
  sigPath = randFile()
  fs.writeFile certPath, cert, (err) ->
    if err
      fs.unlink certPath
      return callback err
    fs.writeFile messagePath, message, (err) ->
      if err
        fs.unlink certPath
        fs.unlink messagePath
        return callback err
      fs.writeFile sigPath, sig, (err) ->
        if err
          fs.unlink certPath
          fs.unlink messagePath
          fs.unlink sigPath
          return callback err
        args = ["-prverify #{certPath}", "-signature #{sigPath}"]
        cmd = "openssl dgst -sha1 #{args.join(" ")} #{messagePath}"
        exec cmd, (err, stdout, stderr) ->
          fs.unlink certPath
          fs.unlink messagePath
          fs.unlink sigPath
          callback err, stdout, stderr
      
exports.genSelfSigned = genSelfSigned
exports.genKey = genKey
exports.genCSR = genCSR
exports.initSerialFile = initSerialFile
exports.verifyCSR = verifyCSR
exports.signCSR = signCSR
exports.getCertFingerprint = getCertFingerprint
exports.sign = sign
exports.verify = verify