certgen = require("security/certgen")
fs = require("fs")
AsyncTestCase = require("util/test").AsyncTestCase
TestSuite = require("util/test").TestSuite
puts = require("util").puts

suite = new TestSuite

suite.newAsyncTest "We can create a certificate and self sign it in one step", (assert, test)->
  certgen.genSelfSigned "key", "cert", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
    assert.isNull(err)
    assert.fileExists "key", ->
      assert.fileExists "cert", ->
        test.done()

suite.newAsyncTest "If we don't pass in material for the subject, generation of the cert should fail", (assert, test) ->
  certgen.genSelfSigned "badkey", "badcert", {}, (err) ->
    assert.ok(err, "We expected it to blow up because the subject doesn't start with a /")
    assert.fileExists "badKey", ->
      assert.fileAbsent "badCert", ->
        test.done()

suite.newAsyncTest "We can generate just a key", (assert, test) ->
  certgen.genKey "justaKey", (err) ->
    assert.isNull(err)
    assert.fileExists "justaKey", ->
      test.done()
    
suite.newAsyncTest "We can generate a cert sign request", (assert, test) ->
  certgen.genSelfSigned "signingKey", "signingCert", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
    assert.isNull(err)
    assert.fileExists "signingKey", ->
      assert.fileExists "signingCert", ->
        certgen.genCSR "signingKey", "outputCSR", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
          assert.isNull(err)
          assert.fileExists "outputCSR", ->
            test.done()

suite.newAsyncTest "We can verify a CSR", (assert, test) ->
  certgen.genSelfSigned "verifyingKey", "verifyingCert", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
    assert.isNull(err)
    certgen.genCSR "verifyingKey", "verifyingCSR", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
      assert.isNull(err)
      certgen.verifyCSR "verifyingCSR", (err) ->
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

suite.newAsyncTest "We can sign a cert using another cert and a verified CSR", (assert, test) ->
  certgen.initSerialFile "ser", -> 
    certgen.genSelfSigned "goodKey", "goodCert", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
      certgen.genKey "plainKey", (err) ->
        certgen.genCSR "plainKey", "plainCSR", {"email":"test@test.com", "hostname":"test.com"}, (err) ->
          certgen.verifyCSR "plainCSR", (err) ->
            certgen.signCSR "plainCSR", "goodCert", "goodKey", "ser", "finalCert", (err) ->
              assert.fileExists "finalCert", ->
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
  
suite.run()
