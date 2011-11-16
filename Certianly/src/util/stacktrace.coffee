printStackTrace = (options) ->
  ex = (if (options and options.e) then options.e else null)
  guess = (if options then !!options.guess else true)
  p = new printStackTrace.implementation()
  result = p.run(ex)
  (if (guess) then p.guessFunctions(result) else result)
printStackTrace.implementation = ->

printStackTrace.implementation:: =
  run: (ex) ->
    mode = @_mode or @mode()
    if mode is "other"
      @other arguments.callee
    else
      ex = ex or (->
        try
          (0)()
        catch e
          return e
      )()
      this[mode] ex

  mode: ->
    try
      (0)()
    catch e
      if e.arguments
        return (@_mode = "chrome")
      else if e.stack
        return (@_mode = "firefox")
      else return (@_mode = "opera")  if window.opera and ("stacktrace" of e)
    @_mode = "other"

  chrome: (e) ->
    e.stack.replace(/^.*?\n/, "").replace(/^.*?\n/, "").replace(/^.*?\n/, "").replace(/^[^\(]+?[\n$]/g, "").replace(/^\s+at\s+/g, "").replace(/^Object.<anonymous>\s*\(/g, "{anonymous}()@").split "\n"

  firefox: (e) ->
    e.stack.replace(/^.*?\n/, "").replace(/(?:\n@:0)?\s+$/m, "").replace(/^\(/g, "{anonymous}(").split "\n"

  opera: (e) ->
    lines = e.message.split("\n")
    ANON = "{anonymous}"
    lineRE = /Line\s+(\d+).*?script\s+(http\S+)(?:.*?in\s+function\s+(\S+))?/i
    i = undefined
    j = undefined
    len = undefined
    i = 4
    j = 0
    len = lines.length

    while i < len
      lines[j++] = (if RegExp.$3 then RegExp.$3 + "()@" + RegExp.$2 + RegExp.$1 else ANON + "()@" + RegExp.$2 + ":" + RegExp.$1) + " -- " + lines[i + 1].replace(/^\s+/, "")  if lineRE.test(lines[i])
      i += 2
    lines.splice j, lines.length - j
    lines

  other: (curr) ->
    ANON = "{anonymous}"
    fnRE = /function\s*([\w\-$]+)?\s*\(/i
    stack = []
    j = 0
    fn = undefined
    args = undefined
    maxStackSize = 10
    while curr and stack.length < maxStackSize
      fn = (if fnRE.test(curr.toString()) then RegExp.$1 or ANON else ANON)
      args = Array::slice.call(curr["arguments"])
      stack[j++] = fn + "(" + printStackTrace.implementation::stringifyArguments(args) + ")"
      break  if curr is curr.caller and window.opera
      curr = curr.caller
    stack

  stringifyArguments: (args) ->
    i = 0

    while i < args.length
      argument = args[i]
      if typeof argument is "object"
        args[i] = "#object"
      else if typeof argument is "function"
        args[i] = "#function"
      else args[i] = "\"" + argument + "\""  if typeof argument is "string"
      ++i
    args.join ","

  sourceCache: {}
  ajax: (url) ->
    req = @createXMLHTTPObject()
    return  unless req
    req.open "GET", url, false
    req.setRequestHeader "User-Agent", "XMLHTTP/1.0"
    req.send ""
    req.responseText

  createXMLHTTPObject: ->
    xmlhttp = undefined
    XMLHttpFactories = [ ->
      new XMLHttpRequest()
    , ->
      new ActiveXObject("Msxml2.XMLHTTP")
    , ->
      new ActiveXObject("Msxml3.XMLHTTP")
    , ->
      new ActiveXObject("Microsoft.XMLHTTP")
    ]
    i = 0

    while i < XMLHttpFactories.length
      try
        xmlhttp = XMLHttpFactories[i]()
        @createXMLHTTPObject = XMLHttpFactories[i]
        return xmlhttp
      i++

  getSource: (url) ->
    @sourceCache[url] = @ajax(url).split("\n")  unless url of @sourceCache
    @sourceCache[url]

  guessFunctions: (stack) ->
    i = 0

    while i < stack.length
      reStack = /{anonymous}\(.*\)@(\w+:\/\/([-\w\.]+)+(:\d+)?[^:]+):(\d+):?(\d+)?/
      frame = stack[i]
      m = reStack.exec(frame)
      if m
        file = m[1]
        lineno = m[4]
        if file and lineno
          functionName = @guessFunctionName(file, lineno)
          stack[i] = frame.replace("{anonymous}", functionName)
      ++i
    stack

  guessFunctionName: (url, lineNo) ->
    try
      return @guessFunctionNameFromLines(lineNo, @getSource(url))
    catch e
      return "getSource failed with url: " + url + ", exception: " + e.toString()

  guessFunctionNameFromLines: (lineNo, source) ->
    reFunctionArgNames = /function ([^(]*)\(([^)]*)\)/
    reGuessFunction = /['"]?([0-9A-Za-z_]+)['"]?\s*[:=]\s*(function|eval|new Function)/
    line = ""
    maxLines = 10
    i = 0

    while i < maxLines
      line = source[lineNo - i] + line
      if line isnt `undefined`
        m = reGuessFunction.exec(line)
        if m and m[1]
          return m[1]
        else
          m = reFunctionArgNames.exec(line)
          return m[1]  if m and m[1]
      ++i
    "(?)"

exports.trace = printStackTrace