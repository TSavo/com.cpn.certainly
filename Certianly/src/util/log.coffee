util = require("util")
sprintf = require("util/sprintf").sprintf
stacktrace = require("util/stacktrace")
loglevels =
  nothing: 0
  crit: 1
  err: 2
  warn: 3
  info: 4
  debug: 5

loglevelStrs = []

logit = (level, inargs) ->
  util.log loglevelStrs[level] + ": " + sprintf.apply({}, inargs)  if level <= loglevel
setLoglevel = (level) ->
  loglevel = loglevels[level]
trace = (label) ->
  err = new Error()
  err.name = "Trace"
  err.message = label or ""
  Error.captureStackTrace err, arguments.callee
  err.stack

loglevel = loglevels.debug
(->
  localf = (attrname) ->
    exports[attrname] = ((level) ->
      logFunc = ->
        args = arguments
        logit.apply null, [ level, args ]

      logFunc.write = (string) ->
        string = string.substring(0, string.length - 1)  if string.charAt(string.length - 1) is "\n"
        logit level, [ string ]

      logFunc
    )(loglevels[attrname])
  for attrname of loglevels
    if loglevels.hasOwnProperty(attrname)
      loglevelStrs[loglevels[attrname]] = attrname
      localf attrname
)()
exports.setLoglevel = setLoglevel
exports.logit = logit
exports.trace = trace