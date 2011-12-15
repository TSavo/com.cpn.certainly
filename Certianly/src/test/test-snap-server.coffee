puts = require("util").debug
inspect = require("util").inspect
TestSuite = require("util/test").TestSuite
fs = require("fs")
HttpClient = require("http/client").HttpClient
TestSuite = require("util/test").TestSuite

client = new HttpClient "10.101.100.100", 8080
suite = new TestSuite
suite.newAsyncTest "We can start up a snap device", (assert, test) ->
  client.post "/Snap/device", 
    snapId:"0001"
    imageId:"ami-00000004"
    instanceType:"m1.large"
    availabilityZone:"compute2"
  , (data) ->
    puts data

suite.run()