fs = require "fs"
puts = require("util").debug
regexCache = {}
Renderer = ->

Renderer:: =
  otag: "{{"
  ctag: "}}"
  pragmas: {}
  buffer: []
  pragmas_implemented:
    "IMPLICIT-ITERATOR": true

  context: {}
  render: (template, context, partials, in_recursion) ->
    unless in_recursion
      @context = context
      @buffer = []
    unless @includes("", template)
      if in_recursion
        return template
      else
        @send template
        return
    template = @render_pragmas(template)
    html = @render_section(template, context, partials)
    html = @render_tags(template, context, partials, in_recursion)  if html is false
    if in_recursion
      html
    else
      @sendLines html

  send: (line) ->
    @buffer.push line  if line isnt ""

  sendLines: (text) ->
    if text
      lines = text.split("\n")
      i = 0

      while i < lines.length
        @send lines[i]
        i++

  render_pragmas: (template) ->
    return template  unless @includes("%", template)
    that = this
    regex = @getCachedRegex("render_pragmas", (otag, ctag) ->
      new RegExp(otag + "%([\\w-]+) ?([\\w]+=[\\w]+)?" + ctag, "g")
    )
    template.replace regex, (match, pragma, options) ->
      throw (message: "This implementation of mustache doesn't understand the '" + pragma + "' pragma")  unless that.pragmas_implemented[pragma]
      that.pragmas[pragma] = {}
      if options
        opts = options.split("=")
        that.pragmas[pragma][opts[0]] = opts[1]
      ""

  render_partial: (name, context, partials) ->
    name = @trim(name)
    throw (message: "unknown_partial '" + name + "'")  if not partials or partials[name] is `undefined`
    return @render(partials[name], context, partials, true)  unless typeof (context[name]) is "object"
    @render partials[name], context[name], partials, true

  render_section: (template, context, partials) ->
    return false  if not @includes("#", template) and not @includes("^", template)
    that = this
    regex = @getCachedRegex("render_section", (otag, ctag) ->
      new RegExp("^([\\s\\S]*?)" + otag + "(\\^|\\#)\\s*(.+)\\s*" + ctag + "\n*([\\s\\S]*?)" + otag + "\\/\\s*\\3\\s*" + ctag + "\\s*([\\s\\S]*)$", "g")
    )
    template.replace regex, (match, before, type, name, content, after) ->
      renderedBefore = (if before then that.render_tags(before, context, partials, true) else "")
      renderedAfter = (if after then that.render(after, context, partials, true) else "")
      renderedContent = undefined
      value = that.find(name, context)
      if type is "^"
        if not value or that.is_array(value) and value.length is 0
          renderedContent = that.render(content, context, partials, true)
        else
          renderedContent = ""
      else if type is "#"
        if that.is_array(value)
          renderedContent = that.map(value, (row) ->
            that.render content, that.create_context(row), partials, true
          ).join("")
        else if that.is_object(value)
          renderedContent = that.render(content, that.create_context(value), partials, true)
        else if typeof value is "function"
          renderedContent = value.call(context, content, (text) ->
            that.render text, context, partials, true
          )
        else if value
          renderedContent = that.render(content, context, partials, true)
        else
          renderedContent = ""
      renderedBefore + renderedContent + renderedAfter

  render_tags: (template, context, partials, in_recursion) ->
    that = this
    new_regex = ->
      that.getCachedRegex "render_tags", (otag, ctag) ->
        new RegExp(otag + "(=|!|>|\\{|%)?([^\\/#\\^]+?)\\1?" + ctag + "+", "g")

    regex = new_regex()
    tag_replace_callback = (match, operator, name) ->
      switch operator
        when "!"
          ""
        when "="
          that.set_delimiters name
          regex = new_regex()
          ""
        when ">"
          that.render_partial name, context, partials
        when "{"
          that.find name, context
        else
          that.escape that.find(name, context)

    lines = template.split("\n")
    i = 0

    while i < lines.length
      lines[i] = lines[i].replace(regex, tag_replace_callback, this)
      @send lines[i]  unless in_recursion
      i++
    lines.join "\n"  if in_recursion

  set_delimiters: (delimiters) ->
    dels = delimiters.split(" ")
    @otag = @escape_regex(dels[0])
    @ctag = @escape_regex(dels[1])

  escape_regex: (text) ->
    unless arguments.callee.sRE
      specials = [ "/", ".", "*", "+", "?", "|", "(", ")", "[", "]", "{", "}", "\\" ]
      arguments.callee.sRE = new RegExp("(\\" + specials.join("|\\") + ")", "g")
    text.replace arguments.callee.sRE, "\\$1"

  find: (name, context) ->
    is_kinda_truthy = (bool) ->
      bool is false or bool is 0 or bool
    name = @trim(name)
    value = undefined
    if name.match(/([a-z_]+)\./g)
      childValue = @walk_context(name, context)
      value = childValue  if is_kinda_truthy(childValue)
    else
      if is_kinda_truthy(context[name])
        value = context[name]
      else value = @context[name]  if is_kinda_truthy(@context[name])
    return value.apply(context)  if typeof value is "function"
    return value  if value isnt `undefined`
    ""

  walk_context: (name, context) ->
    path = name.split(".")
    value_context = (if (context[path[0]] isnt `undefined`) then context else @context)
    value = value_context[path.shift()]
    while value isnt `undefined` and path.length > 0
      value_context = value
      value = value[path.shift()]
    return value.apply(value_context)  if typeof value is "function"
    value

  includes: (needle, haystack) ->
    haystack.indexOf(@otag + needle) isnt -1

  escape: (s) ->
    s = String((if s is null then "" else s))
    s.replace /&(?!\w+;)|["'<>\\]/g, (s) ->
      switch s
        when "&"
          "&amp;"
        when "\""
          "&quot;"
        when "'"
          "&#39;"
        when "<"
          "&lt;"
        when ">"
          "&gt;"
        else
          s

  create_context: (_context) ->
    if @is_object(_context)
      _context
    else
      iterator = "."
      iterator = @pragmas["IMPLICIT-ITERATOR"].iterator  if @pragmas["IMPLICIT-ITERATOR"]
      ctx = {}
      ctx[iterator] = _context
      ctx

  is_object: (a) ->
    a and typeof a is "object"

  is_array: (a) ->
    Object::toString.call(a) is "[object Array]"

  trim: (s) ->
    s.replace /^\s*|\s*$/g, ""

  map: (array, fn) ->
    if typeof array.map is "function"
      array.map fn
    else
      r = []
      l = array.length
      i = 0

      while i < l
        r.push fn(array[i])
        i++
      r

  getCachedRegex: (name, generator) ->
    byOtag = regexCache[@otag]
    byOtag = regexCache[@otag] = {}  unless byOtag
    byCtag = byOtag[@ctag]
    byCtag = byOtag[@ctag] = {}  unless byCtag
    regex = byCtag[name]
    regex = byCtag[name] = generator(@otag, @ctag)  unless regex
    regex



to_html = (template, view, partials, send_fun) ->
  renderer = new Renderer()
  renderer.send = send_fun  if send_fun
  renderer.render template, view or {}, partials
  renderer.buffer.join "\n"  unless send_fun

partial = (template, view, partials, callback) ->
  fs.readFile "templates/#{template}.mustache", (err, data) ->
    if err
      callback err if callback
      return
    chunk = ""
    to_html data.toString(), view, partials, (data) ->
      chunk += data
    callback null, chunk if callback

render_partial = (response, partialName, view, partials, callback) ->
  partial partialName, view, partials, (err, data) ->
    if err
      puts "Failed to render #{partialName}: #{err}"
      response.write "Failed to render #{partialName}: #{err}"
      callback err
      return
    response.write data
    callback() if callback
    
view = (partialName, context) ->
  (response, request) ->
    render_partial response, partialName, context, null, ->
      response.end()
      
exports.to_html = to_html
exports.partial = partial
exports.render_partial = render_partial
exports.view = view      

