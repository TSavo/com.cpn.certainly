Application = require("http/application").Application
view = require("http/mustache").view
cert_dispatcher = require("security/cert_dispatcher")
puts = require("util").debug

app = new Application
app.addPage("/cert/csr",
  POST:cert_dispatcher.newCSR
).addPage("/cert",
  POST:cert_dispatcher.genKey
).addPage("/cert/sign",
  POST:cert_dispatcher.signCSR
).addPage("/cert/ca",
  POST:cert_dispatcher.genCA
).addPage("/cert/pkcs12",
  POST:cert_dispatcher.pkcs12
).addPage("/dieAHorribleDeath",
  GET:(request, response)->
    puts "Server is shutting down."
    response.write "What a world... what a world..."
    response.end()
    app.stop()
).start()
exports.app = app
