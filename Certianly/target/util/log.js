(function() {
  var logit, loglevel, loglevelStrs, loglevels, setLoglevel, sprintf, stacktrace, trace, util;

  util = require("util");

  sprintf = require("util/sprintf").sprintf;

  stacktrace = require("util/stacktrace");

  loglevels = {
    nothing: 0,
    crit: 1,
    err: 2,
    warn: 3,
    info: 4,
    debug: 5
  };

  loglevelStrs = [];

  logit = function(level, inargs) {
    if (level <= loglevel) {
      return util.log(loglevelStrs[level] + ": " + sprintf.apply({}, inargs));
    }
  };

  setLoglevel = function(level) {
    var loglevel;
    return loglevel = loglevels[level];
  };

  trace = function(label) {
    var err;
    err = new Error();
    err.name = "Trace";
    err.message = label || "";
    Error.captureStackTrace(err, arguments.callee);
    return err.stack;
  };

  loglevel = loglevels.debug;

  (function() {
    var attrname, localf, _results;
    localf = function(attrname) {
      return exports[attrname] = (function(level) {
        var logFunc;
        logFunc = function() {
          var args;
          args = arguments;
          return logit.apply(null, [level, args]);
        };
        logFunc.write = function(string) {
          if (string.charAt(string.length - 1) === "\n") {
            string = string.substring(0, string.length - 1);
          }
          return logit(level, [string]);
        };
        return logFunc;
      })(loglevels[attrname]);
    };
    _results = [];
    for (attrname in loglevels) {
      if (loglevels.hasOwnProperty(attrname)) {
        loglevelStrs[loglevels[attrname]] = attrname;
        _results.push(localf(attrname));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  })();

  exports.setLoglevel = setLoglevel;

  exports.logit = logit;

  exports.trace = trace;

}).call(this);
