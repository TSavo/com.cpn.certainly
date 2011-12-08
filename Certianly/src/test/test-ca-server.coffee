puts = require("util").debug
inspect = require("util").inspect
TestSuite = require("util/test").TestSuite
app = require("http/index").app
fs = require("fs")
HttpClient = require("http/client").HttpClient
TestSuite = require("util/test").TestSuite

client = new HttpClient "localhost", 8888
suite = new TestSuite

suite.newAsyncTest "We can generate a root, a new key and CSR, and get it signed by the root", (assert, test) ->
  assert.fileAbsent "certs/root.cert"
  assert.fileAbsent "certs/root.key"
  client.post "/cert/root", 
    daysValidFor:7300
    certName:"root"
    subject:"/C=US/ST=California/O=ClearPath Networks/OU=Engineering Department/CN=ClearPath Networks Root Certificate/emailAddress=certs@clearpathnet.com"
  , (data) ->
    assert.isTrue data.success
    assert.fileExists "certs/root.cert"
    assert.fileExists "certs/root.key"
    client.post "/cert/csr", 
      daysValidFor:7300
      certName:"partner"
      subject:"/C=US/ST=California/O=ClearPath Networks/OU=Engineering Department/CN=ClearPath Networks Partner Root Certificate/emailAddress=certs@clearpathnet.com"
    , (data) ->
      assert.strictEqual "partner", data.certName
      assert.isTrue data.csr.length > 0
      assert.fileExists "certs/partner.key"
      assert.fileAbsent "certs/partner.cert"
      data.ca = "root"
      client.post "/cert/sign", data, (data) ->
        assert.isTrue data.cert.length > 0
        assert.fileAbsent "certs/partner.cert"
        data.certName = "partner"
        client.post "/cert/install", data, (data) ->
          assert.isTrue data.success
          assert.fileExists "certs/partner.cert"      
          client.post "/cert/signer",
            daysValidFor:7300
            certName:"snap"
            ca:"partner"
            subject:"/C=US/ST=California/O=ClearPath Networks/OU=Engineering Department/CN=ClearPath Networks Partner Snap Root Certificate/emailAddress=certs@clearpathnet.com"
          , (data) ->
            assert.isTrue data.success
            assert.fileExists "certs/snap.key"
            assert.fileExists "certs/snap.cert"
            client.post "/cert",
              daysValidFor:365
              ca:"snap"
              subject:"/C=US/ST=California/O=ClearPath Networks/OU=Engineering Department/CN=snap-0001/emailAddress=certs@clearpathnet.com"
            , (data) ->
              assert.isTrue data.cert.length > 0
              assert.isTrue data.key.length > 0
              test.done()
            
suite.after = ->
  client.get "/dieAHorribleDeath", (data) ->
  files = fs.readdirSync "certs"
  for x in files
    fs.unlinkSync "certs/#{x}"
  fs.rmdirSync "certs"
  fs.renameSync "certs.backup", "certs"

fs.rename "certs", "certs.backup"
fs.mkdir "certs"
 
suite.run()

