certgen = require("security/certgen")
fs = require("fs")
AsyncTestCase = require("util/test").AsyncTestCase
TestSuite = require("util/test").TestSuite
puts = require("util").puts

suite = new TestSuite

suite.newAsyncTest "We can create a certificate and self sign it in one step", (assert, test)->
  certgen.genSelfSigned {"commonName":"test@test.com", "organizationalUnitName":"test.com", "organizationName":"orgName"}, 1095, (err, key, cert) ->
    assert.isNull(err)
    assert.isTrue(key, "No key")
    assert.isTrue(cert, "No cert")
    test.done()

suite.newAsyncTest "If we don't pass in material for the subject, generation of the cert should fail", (assert, test) ->
  certgen.genSelfSigned {}, 1095, (err) ->
    assert.ok(err, "We expected it to blow up because the subject doesn't start with a /")
    test.done()

suite.newAsyncTest "We can generate just a key", (assert, test) ->
  certgen.genKey (err, key) ->
    assert.isNull(err)
    assert.isTrue(key, "No key")
    test.done()
    
suite.newAsyncTest "We can generate a cert sign request", (assert, test) ->
  certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, key, cert) ->
    assert.isNull(err)
    certgen.genCSR key, {"email":"test@test.com", "hostname":"test.com"}, (err, csr) ->
      assert.isNull err
      assert.isTrue csr, "No CRS" 
      test.done()

suite.newAsyncTest "We can verify a CSR", (assert, test) ->
  certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, key, cert) ->
    assert.isNull(err)
    certgen.genCSR key, {"email":"test@test.com", "hostname":"test.com"}, (err, csr) ->
      assert.isNull(err)
      certgen.verifyCSR csr, (err) ->
        assert.isNull(err)
        test.done()
        
suite.newAsyncTest "Verifying a bad CSR will fail", (assert, test) ->
  certgen.verifyCSR "nonExistantCSR", (err) ->
    assert.isTrue(err, "We expected it to fail when verifying a non-existant CSR")
    test.done()

suite.newAsyncTest "We can initialize our serial file", (assert, test) ->
  certgen.initSerialFile "ser", ->
    assert.fileExists "ser", ->
      test.done()

suite.newAsyncTest "We can sign a cert using another cert + key and a verified CSR", (assert, test) ->
  certgen.initSerialFile "ser", -> 
    certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, signerKey, cert) ->
      certgen.genKey (err, key) ->
        certgen.genCSR key, {"email":"test@test.com", "hostname":"test.com"}, (err, csr) ->
          certgen.verifyCSR csr, (err) ->
            certgen.signCSR csr, cert, signerKey, "ser", "finalCert", 1095, (err) ->
              assert.fileExists "finalCert", ->
                test.done()

suite.newAsyncTest "We can get the fingerprint of a cert", (assert, test) ->
  certgen.getCertFingerprint "finalCert", (err, fingerprint) ->
    assert.isNull(err)
    assert.equal fingerprint.length, 59, "We expected out fingerprint to be 59 chars."
    test.done()

suite.newAsyncTest "We can sign and verify a message", (assert, test) ->
  message = "12345"
  certgen.sign "key", message, "sig", (err) ->
    assert.isNull err, "Signing failed" 
    certgen.verify "key", "sig", message, "out", (err, stdout, stderr) ->
      assert.isNull err, "Verification failed"
      test.done()
      

suite.afterSuite = ->
  fs.unlink "key"
  fs.unlink "cert"
  fs.unlink "badKey"
  fs.unlink "justaKey"
  fs.unlink "signingKey"
  fs.unlink "signingCert"
  fs.unlink "outputCSR"
  fs.unlink "verifyingCert"
  fs.unlink "verifyingCSR"
  fs.unlink "verifyingKey"
  fs.unlink "goodKey"
  fs.unlink "goodCert"
  fs.unlink "plainKey"
  fs.unlink "plainCert"
  fs.unlink "plainCSR"
  fs.unlink "ser"
  fs.unlink "finalCert"
  fs.unlink "sig"
  fs.unlink "messageToBeSigned"
  fs.unlink "messageToBeVerified"

suite.run()
