exec = require("child_process").exec
fs = require("fs")
puts = require("util").puts



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
genSelfSigned = (outputKey, outputCert, options, daysValidFor, callback) ->
  reqArgs = [ "-batch", "-x509", "-nodes", "-days #{daysValidFor}", "-subj \"#{buildSubj(options)}\"", "-sha1", "-newkey rsa:2048", "-keyout \"#{outputKey}\"", "-out \"#{outputCert}\"" ]
  cmd = "openssl req " + reqArgs.join(" ")
  exec cmd, (err, stdout, stderr) ->
    callback err, stdout, stderr
    
    
###*
 * Generate an RSA key.
 *
 * @param {String} outputKey Location to output the key to.
 * @param {Function} callback Callback fired with (err).
###
genKey = (outputKey, callback) ->
  args = [ "-out \"#{outputKey}\"", 2048 ]
  cmd = "openssl genrsa " + args.join(" ")
  exec cmd, (err, stdout, stderr) ->
    callback err, stdout, stderr if callback
    
###*
 * Generate a CSR for the specified key, and pass it back as a string through
 * a callback.
 * @param {String} inputKey File to read the key from.
 * @param {String} outputCSR File to store the CSR to.
 * @param {Object} options An options object with optional email and hostname.
 * @param {Function} callback Callback fired with (err, csrText).
###
genCSR = (inputKey, outputCSR, options, callback) ->
  args = [ "-batch", "-new", "-nodes", "-subj \"#{buildSubj(options)}\"", "-key \"#{inputKey}\"", "-out \"#{outputCSR}\"" ]
  cmd = "openssl req " + args.join(" ")
  exec cmd, (err, stdout, stderr) ->
    callback err, stdout, stderr if callback
    
###*
 * Initialize an openssl '.srl' file for serial number tracking.
 * @param {String} srlPath Path to use for the srl file.
 * @param {Function} callback Callback fired with (err).
###
initSerialFile = (srlPath, callback) ->
  fs.writeFile srlPath, "00", callback

###*
 * Verify a CSR.
 * @param {String} csrPath Path to the CSR file.
 * @param {Function} callback Callback fired with (err).
###
verifyCSR = (csrPath, callback) ->
  args = [ "-verify", "-noout", "-in \"#{csrPath}\"" ]
  cmd = "openssl req #{args.join(" ")}"
  exec cmd, (err, stdout, stderr) ->
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
signCSR = (csrPath, caCertPath, caKeyPath, caSerialPath, outputCert, daysValidFor, callback) ->
  args = [ "-req", "-days #{daysValidFor}", "-CA \"#{caCertPath}\"", "-CAkey \"#{caKeyPath}\"", "-CAserial \"#{caSerialPath}\"", "-in #{csrPath}", "-out #{outputCert}" ]
  cmd = "openssl x509 #{args.join(" ")}"
  exec cmd, (err, stdout, stderr) ->
    callback err, stdout, stderr


###*
 * Retrieve a SHA1 fingerprint of a certificate.
 * @param {String} certPath Path to the certificate.
 * @param {Function} callback Callback fired with (err, fingerprint).
###
getCertFingerprint = (certPath, callback) ->
  args = [ "-noout", "-in \"#{certPath}\"", "-fingerprint", "-sha1" ]
  cmd = "openssl x509 #{args.join(" ")}"
  exec cmd, (err, stdout, stderr) ->
    if err
      callback err, stdout, stderr
      return
    segments = stdout.split("=")
    if segments.length isnt 2 or segments[0] isnt "SHA1 Fingerprint"
      callback new Error("Unexpected output from openssl"), stdout, stderr
      return
    callback null, (segments[1] || '').replace(/^\s+|\s+$/g, '')

sign = (keyPath, message, signaturePath, callback) ->
  args = ["-sign #{keyPath}", "-out #{signaturePath}"]
  fs.writeFile "messageToBeSigned", message, ->
    cmd = "openssl dgst -sha1 #{args.join(" ")} messageToBeSigned"
    exec cmd, (err, stdout, stderr) ->
      callback err, stdout, stderr

verify = (certPath, signaturePath, message, out, callback) ->
  args = ["-prverify #{certPath}", "-signature #{signaturePath}"]
  fs.writeFile "messageToBeVerified", message, ->      
    cmd = "openssl dgst -sha1 #{args.join(" ")} messageToBeVerified"
    exec cmd, (err, stdout, stderr) ->
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