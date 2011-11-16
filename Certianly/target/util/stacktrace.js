(function() {
  var printStackTrace;

  printStackTrace = function(options) {
    var ex, guess, p, result;
    ex = (options && options.e ? options.e : null);
    guess = (options ? !!options.guess : true);
    p = new printStackTrace.implementation();
    result = p.run(ex);
    if (guess) {
      return p.guessFunctions(result);
    } else {
      return result;
    }
  };

  printStackTrace.implementation = function() {};

  printStackTrace.implementation.prototype = {
    run: function(ex) {
      var mode;
      mode = this._mode || this.mode();
      if (mode === "other") {
        return this.other(arguments.callee);
      } else {
        ex = ex || (function() {
          try {
            return 0.();
          } catch (e) {
            return e;
          }
        })();
        return this[mode](ex);
      }
    },
    mode: function() {
      try {
        0.();
      } catch (e) {
        if (e.arguments) {
          return (this._mode = "chrome");
        } else if (e.stack) {
          return (this._mode = "firefox");
        } else {
          if (window.opera && ("stacktrace" in e)) return (this._mode = "opera");
        }
      }
      return this._mode = "other";
    },
    chrome: function(e) {
      return e.stack.replace(/^.*?\n/, "").replace(/^.*?\n/, "").replace(/^.*?\n/, "").replace(/^[^\(]+?[\n$]/g, "").replace(/^\s+at\s+/g, "").replace(/^Object.<anonymous>\s*\(/g, "{anonymous}()@").split("\n");
    },
    firefox: function(e) {
      return e.stack.replace(/^.*?\n/, "").replace(/(?:\n@:0)?\s+$/m, "").replace(/^\(/g, "{anonymous}(").split("\n");
    },
    opera: function(e) {
      var ANON, i, j, len, lineRE, lines;
      lines = e.message.split("\n");
      ANON = "{anonymous}";
      lineRE = /Line\s+(\d+).*?script\s+(http\S+)(?:.*?in\s+function\s+(\S+))?/i;
      i = void 0;
      j = void 0;
      len = void 0;
      i = 4;
      j = 0;
      len = lines.length;
      while (i < len) {
        if (lineRE.test(lines[i])) {
          lines[j++] = (RegExp.$3 ? RegExp.$3 + "()@" + RegExp.$2 + RegExp.$1 : ANON + "()@" + RegExp.$2 + ":" + RegExp.$1) + " -- " + lines[i + 1].replace(/^\s+/, "");
        }
        i += 2;
      }
      lines.splice(j, lines.length - j);
      return lines;
    },
    other: function(curr) {
      var ANON, args, fn, fnRE, j, maxStackSize, stack;
      ANON = "{anonymous}";
      fnRE = /function\s*([\w\-$]+)?\s*\(/i;
      stack = [];
      j = 0;
      fn = void 0;
      args = void 0;
      maxStackSize = 10;
      while (curr && stack.length < maxStackSize) {
        fn = (fnRE.test(curr.toString()) ? RegExp.$1 || ANON : ANON);
        args = Array.prototype.slice.call(curr["arguments"]);
        stack[j++] = fn + "(" + printStackTrace.implementation.prototype.stringifyArguments(args) + ")";
        if (curr === curr.caller && window.opera) break;
        curr = curr.caller;
      }
      return stack;
    },
    stringifyArguments: function(args) {
      var argument, i;
      i = 0;
      while (i < args.length) {
        argument = args[i];
        if (typeof argument === "object") {
          args[i] = "#object";
        } else if (typeof argument === "function") {
          args[i] = "#function";
        } else {
          if (typeof argument === "string") args[i] = "\"" + argument + "\"";
        }
        ++i;
      }
      return args.join(",");
    },
    sourceCache: {},
    ajax: function(url) {
      var req;
      req = this.createXMLHTTPObject();
      if (!req) return;
      req.open("GET", url, false);
      req.setRequestHeader("User-Agent", "XMLHTTP/1.0");
      req.send("");
      return req.responseText;
    },
    createXMLHTTPObject: function() {
      var XMLHttpFactories, i, xmlhttp, _results;
      xmlhttp = void 0;
      XMLHttpFactories = [
        function() {
          return new XMLHttpRequest();
        }, function() {
          return new ActiveXObject("Msxml2.XMLHTTP");
        }, function() {
          return new ActiveXObject("Msxml3.XMLHTTP");
        }, function() {
          return new ActiveXObject("Microsoft.XMLHTTP");
        }
      ];
      i = 0;
      _results = [];
      while (i < XMLHttpFactories.length) {
        try {
          xmlhttp = XMLHttpFactories[i]();
          this.createXMLHTTPObject = XMLHttpFactories[i];
          return xmlhttp;
        } catch (_error) {}
        _results.push(i++);
      }
      return _results;
    },
    getSource: function(url) {
      if (!(url in this.sourceCache)) {
        this.sourceCache[url] = this.ajax(url).split("\n");
      }
      return this.sourceCache[url];
    },
    guessFunctions: function(stack) {
      var file, frame, functionName, i, lineno, m, reStack;
      i = 0;
      while (i < stack.length) {
        reStack = /{anonymous}\(.*\)@(\w+:\/\/([-\w\.]+)+(:\d+)?[^:]+):(\d+):?(\d+)?/;
        frame = stack[i];
        m = reStack.exec(frame);
        if (m) {
          file = m[1];
          lineno = m[4];
          if (file && lineno) {
            functionName = this.guessFunctionName(file, lineno);
            stack[i] = frame.replace("{anonymous}", functionName);
          }
        }
        ++i;
      }
      return stack;
    },
    guessFunctionName: function(url, lineNo) {
      try {
        return this.guessFunctionNameFromLines(lineNo, this.getSource(url));
      } catch (e) {
        return "getSource failed with url: " + url + ", exception: " + e.toString();
      }
    },
    guessFunctionNameFromLines: function(lineNo, source) {
      var i, line, m, maxLines, reFunctionArgNames, reGuessFunction;
      reFunctionArgNames = /function ([^(]*)\(([^)]*)\)/;
      reGuessFunction = /['"]?([0-9A-Za-z_]+)['"]?\s*[:=]\s*(function|eval|new Function)/;
      line = "";
      maxLines = 10;
      i = 0;
      while (i < maxLines) {
        line = source[lineNo - i] + line;
        if (line !== undefined) {
          m = reGuessFunction.exec(line);
          if (m && m[1]) {
            return m[1];
          } else {
            m = reFunctionArgNames.exec(line);
            if (m && m[1]) return m[1];
          }
        }
        ++i;
      }
      return "(?)";
    }
  };

  exports.trace = printStackTrace;

}).call(this);
