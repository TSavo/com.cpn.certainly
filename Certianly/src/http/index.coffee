Application = require("http/application").Application
view = require("http/mustache").view
cert_dispatcher = require("security/cert_dispatcher")

app = new Application
app.addPage("/cert/install",
  GET:view("installCertForm"),
  POST:cert_dispatcher.installCert
).addPage("/cert",
  GET:cert_dispatcher.showCerts
).addPage("/cert/new",
  GET:view("newCertForm"),
  POST:cert_dispatcher.newCert
).addPage("/cert/newSigner",
  GET:view("newSignerForm"),
  POST:cert_dispatcher.newSigner
).addPage("/cert/genCA",
  GET:view("genCAForm"),
  POST:cert_dispatcher.genCA
).addPage("/cert/bundle",
  GET:view("bundleCertsForm"),
  POST:cert_dispatcher.bundleCerts
).addPage("/dieAHorribleDeath",
  GET:(response, request)->
    response.write "What a world... what a world..."
    response.end()
    process.exit()
).start()
