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
  client.post "/cert/ca", 
    daysValidFor:7300
    subject:
      C:"US"
      ST:"California"
      O:"ClearPath Networks"
      OU:"Engineering Department"
      CN:"ClearPath Networks Root Certificate"
      emailAddress:"certs@clearpathnet.com"
      subjectAltName:"DNS:os115.cpncloud.com"
  , (data) ->
    assert.isTrue data.privateKey?.length > 0
    assert.isTrue data.cert?.length > 0
    cert = data.cert
    key = data.privateKey
    client.post "/cert/csr", 
      subject:
        C:"US"
        ST:"California"
        O:"ClearPath Networks"
        OU:"Engineering Department"
        CN:"ClearPath Networks Partner Root Certificate"
        emailAddress:"certs@clearpathnet.com"
        subjectAltName:"email:copy"
    , (data) ->
      assert.isTrue data.csr.length > 0, "We were expecting a valid CSR"
      assert.isTrue data.privateKey.length > 0, "We were expecting our privateKey to be returned to us"
      data.cert = cert
      data.privateKey = key
      data.daysValidFor = 7300
      client.post "/cert/sign", data, (data) ->
        assert.isTrue data.cert?.length > 0, "We were expecting a cert back"
        client.post "/pkcs12",
          privateKey: key
          cert: cert
        , (data) ->
          assert.isTrue data.pkcs12.length > 0, "Was expecting a pkcs12 to be valid"
          test.done()


suite.after = ->
  client.get "/dieAHorribleDeath"
###, (data) ->
    files = fs.readdirSync "certs"
    for x in files
      fs.unlinkSync "certs/#{x}"
    fs.rmdirSync "certs"
    fs.stat "certs.backup", (err, stat) ->
      if stat? and not err?  
        fs.renameSync "certs.backup", "certs"
fs.stat "certs", (err, stat) ->
  if err and not stat?
    fs.mkdirSync "certs"
  else
    fs.renameSync "certs", "certs.backup"
    fs.mkdirSync "certs"
###
suite.run()

