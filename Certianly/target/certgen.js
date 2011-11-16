(function() {
  var buildSubj, exec, fs, genCSR, genKey, genSelfSigned, getCertFingerprint, initSerialFile, log, signCSR, verifyCSR;

  exec = require("child_process").exec;

  fs = require("fs");

  log = require("util/log");

  /**
   * Construct an x509 -subj argument from an options object.
   * @param {Object} options An options object with optional email and hostname.
   * @return {String} A string suitable for use with x509 as a -subj argument.
  */

  buildSubj = function(options) {
    var attrMap, key, subject;
    attrMap = {
      hostname: "CN",
      email: "emailAddress"
    };
    subject = "";
    key = void 0;
    for (key in attrMap) {
      if (attrMap.hasOwnProperty(key) && options.hasOwnProperty(key)) {
        subject = "" + subject + "/" + attrMap[key] + "=" + options[key];
      }
    }
    return subject;
  };

  /**
   * Generates a Self signed X509 Certificate.
   *
   * @param {String} outputKey Path to write the private key to.
   * @param {String} outputCert Path to write the certificate to.
   * @param {Object} options An options object with optional email and hostname.
   * @param {Function} callback fired with (err).
  */

  genSelfSigned = function(outputKey, outputCert, options, callback) {
    var cmd, reqArgs;
    reqArgs = ["-batch", "-x509", "-nodes", "-days 1825", "-subj \"" + (buildSubj(options)) + "\"", "-sha1", "-newkey rsa:2048", "-keyout \"" + outputKey + "\"", "-out \"" + outputCert + "\""];
    cmd = "openssl req " + reqArgs.join(" ");
    return exec(cmd, function(err, stdout, stderr) {
      if (err) {
        log.err("openssl command failed: " + cmd + " error was: " + err, err, stdout, stderr);
      }
      return callback(err);
    });
  };

  /**
   * Generate an RSA key.
   *
   * @param {String} outputKey Location to output the key to.
   * @param {Function} callback Callback fired with (err).
  */

  genKey = function(outputKey, callback) {
    var args, cmd;
    args = ["-out \"${outputKey}\"", 2048];
    cmd = "openssl genrsa " + args.join(" ");
    return exec(cmd, function(err, stdout, stderr) {
      if (err) log.err("openssl command failed: " + cmd, stdout, stderr);
      return callback(err);
    });
  };

  /**
   * Generate a CSR for the specified key, and pass it back as a string through
   * a callback.
   * @param {String} inputKey File to read the key from.
   * @param {String} outputCSR File to store the CSR to.
   * @param {Object} options An options object with optional email and hostname.
   * @param {Function} callback Callback fired with (err, csrText).
  */

  genCSR = function(inputKey, outputCSR, options, callback) {
    var args, cmd;
    args = ["-batch", "-new", "-nodes", "-subj \"${buildSubj(options)}\"", "-key \"" + inputKey + "\"", "-out \"" + outputCSR + "\""];
    cmd = "openssl req " + args.join(" ");
    return exec(cmd, function(err, stdout, stderr) {
      if (err) log.err("openssl command failed: " + cmd, stdout, stderr);
      return callback(err);
    });
  };

  /**
   * Initialize an openssl '.srl' file for serial number tracking.
   * @param {String} srlPath Path to use for the srl file.
   * @param {Function} callback Callback fired with (err).
  */

  initSerialFile = function(srlPath, callback) {
    return fs.writeFile(srlPath, "00", callback);
  };

  /**
   * Verify a CSR.
   * @param {String} csrPath Path to the CSR file.
   * @param {Function} callback Callback fired with (err).
  */

  verifyCSR = function(csrPath, callback) {
    var args, cmd;
    args = ["-verify", "-noout", "-in \"" + csrPath + "\""];
    cmd = "openssl req " + (args.join(" "));
    return exec(cmd, function(err, stdout, stderr) {
      if (err) {
        if (!(stderr && stderr.match(/verify failure/))) {
          log.err("openssl command failed: " + cmd);
        }
        err = new Error("Invalid CSR received");
      }
      return callback(err);
    });
  };

  /**
   * Sign a CSR and store the resulting certificate to the specified location
   * @param {String} csrPath Path to the CSR file.
   * @param {String} caCertPath Path to the CA certificate.
   * @param {String} caKeyPath Path to the CA key.
   * @param {String} caSerialPath Path to the CA serial number file.
   * @param {String} outputCert Path at which to store the certificate.
   * @param {Function} callback Callback fired with (err).
  */

  signCSR = function(csrPath, caCertPath, caKeyPath, caSerialPath, outputCert, callback) {
    var args, cmd;
    args = ["-req", "-days 1825", "-CA \"" + caCertPath + "\"", "-CAkey \"" + caKeyPath + "\"", "-CAserial \"" + caSerialPath + "\"", "-in " + csrPath, "-out " + outputCert];
    cmd = "openssl x509 " + (args.join(" "));
    return exec(cmd, function(err, stdout, stderr) {
      if (err) log.err("openssl command failed: " + cmd, stdout, stderr);
      return callback(err);
    });
  };

  /**
   * Retrieve a SHA1 fingerprint of a certificate.
   * @param {String} certPath Path to the certificate.
   * @param {Function} callback Callback fired with (err, fingerprint).
  */

  getCertFingerprint = function(certPath, callback) {
    var args, cmd;
    args = ["-noout", "-in \"" + certPath + "\"", "-fingerprint", "-sha1"];
    cmd = "openssl x509 " + (args.join(" "));
    return exec(cmd, function(err, stdout, stderr) {
      var segments;
      if (err) {
        log.err("openssl command failed: " + cmd, stdout, stderr);
        callback(err);
        return;
      }
      segments = stdout.split("=");
      if (segments.length !== 2 || segments[0] !== "SHA1 Fingerprint") {
        callback(new Error("Unexpected output from openssl"));
        return;
      }
      return callback(null, (segments[1] || '').replace(/^\s+|\s+$/g, ''));
    });
  };

  exports.genSelfSigned = genSelfSigned;

  exports.genKey = genKey;

  exports.genCSR = genCSR;

  exports.initSerialFile = initSerialFile;

  exports.verifyCSR = verifyCSR;

  exports.signCSR = signCSR;

  exports.getCertFingerprint = getCertFingerprint;

}).call(this);
