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

suite.newAsyncTest "We can generate just a key", (assert, test) ->
  certgen.genKey (err, key) ->
    assert.isNull(err)
    assert.isTrue(key, "No key")
    test.done()


suite.newAsyncTest "If we don't pass in material for the subject, generation of the cert should fail", (assert, test) ->
  certgen.genSelfSigned {}, 1095, (err) ->
    assert.ok(err, "We expected it to blow up because the subject doesn't start with a /")
    test.done()

suite.newAsyncTest "We can generate a cert sign request", (assert, test) ->
  certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, key, cert) ->
    assert.isNull(err)
    certgen.genCSR key, {"email":"test@test.com", "hostname":"test.com"}, (err, csr) ->
      assert.isNull err
      assert.isTrue csr, "No CSR" 
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
    assert.isTrue(err, "We expected it to fail when verifying a non-existent CSR")
    test.done()
    

suite.newAsyncTest "We can initialize our serial file", (assert, test) ->
  certgen.initSerialFile  ->
    assert.fileExists "serial.srl", ->
      test.done()

suite.newAsyncTest "We can sign a cert using another cert + key and a verified CSR", (assert, test) ->
  certgen.initSerialFile -> 
    certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, signerKey, cert) ->
      assert.isNull err
      certgen.genKey (err, key) ->
        assert.isNull err
        certgen.genCSR key, {"email":"test@test.com", "hostname":"test.com"}, (err, csr) ->
          assert.isNull err
          certgen.verifyCSR csr, (err) ->
            assert.isNull err
            certgen.signCSR csr, cert, signerKey, 1095, (err, finalCert) ->
              assert.isNull err
              assert.isTrue finalCert.toString().indexOf("BEGIN CERTIFICATE") > 0, "We expected our cert to be in a valid format: #{finalCert}"
              test.done()

suite.newAsyncTest "We can get the fingerprint of a cert", (assert, test) ->
  certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, signerKey, cert) ->
    certgen.getCertFingerprint cert, (err, fingerprint) ->
      assert.isNull(err)
      assert.equal fingerprint.length, 59, "We expected out fingerprint to be 59 chars."
      test.done()

suite.newAsyncTest "We can sign and verify a message", (assert, test) ->
  message = "12345"
  certgen.genSelfSigned {"email":"test@test.com", "hostname":"test.com"}, 1095, (err, signerKey, cert) ->
    certgen.sign signerKey, message, (err, sig) ->
      assert.isNull err, "Signing failed" 
      certgen.verify signerKey, sig, message, (err, stdout, stderr) ->
        assert.isNull err, "Verification failed"
        test.done()
      

suite.run()
