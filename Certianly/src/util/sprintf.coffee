util = require("util")
sprintf = (->
  get_type = (variable) ->
    Object::toString.call(variable).slice(8, -1).toLowerCase()
  str_repeat = (input, multiplier) ->
    output = []

    while multiplier > 0
      output[--multiplier] = input
    output.join ""
  str_format = ->
    str_format.cache[arguments[0]] = str_format.parse(arguments[0])  unless str_format.cache.hasOwnProperty(arguments[0])
    str_format.format.call null, str_format.cache[arguments[0]], arguments

  str_format.format = (parse_tree, argv) ->
    cursor = 1
    tree_length = parse_tree.length
    node_type = ""
    arg = undefined
    output = []
    i = undefined
    k = undefined
    match = undefined
    pad = undefined
    pad_character = undefined
    pad_length = undefined
    i = 0
    while i < tree_length
      node_type = get_type(parse_tree[i])
      if node_type is "string"
        output.push parse_tree[i]
      else if node_type is "array"
        match = parse_tree[i]
        if match[2]
          arg = argv[cursor]
          k = 0
          while k < match[2].length
            throw (sprintf("[sprintf] property \"%s\" does not exist", match[2][k]))  unless arg.hasOwnProperty(match[2][k])
            arg = arg[match[2][k]]
            k++
        else if match[1]
          arg = argv[match[1]]
        else
          arg = argv[cursor++]
        throw (sprintf("[sprintf] expecting number but found %s", get_type(arg)))  if /[^sO]/.test(match[8]) and (get_type(arg) isnt "number")
        switch match[8]
          when "b"
            arg = arg.toString(2)
          when "c"
            arg = String.fromCharCode(arg)
          when "d"
            arg = parseInt(arg, 10)
          when "e"
            arg = (if match[7] then arg.toExponential(match[7]) else arg.toExponential())
          when "f"
            arg = (if match[7] then parseFloat(arg).toFixed(match[7]) else parseFloat(arg))
          when "O"
            arg = util.inspect(arg)
          when "o"
            arg = arg.toString(8)
          when "s"
            arg = (if (arg = String(arg)) and match[7] then arg.substring(0, match[7]) else arg)
          when "u"
            arg = Math.abs(arg)
          when "x"
            arg = arg.toString(16)
          when "X"
            arg = arg.toString(16).toUpperCase()
        arg = (if /[def]/.test(match[8]) and match[3] and arg >= 0 then "+" + arg else arg)
        pad_character = (if match[4] then (if match[4] is "0" then "0" else match[4].charAt(1)) else " ")
        pad_length = match[6] - String(arg).length
        pad = (if match[6] then str_repeat(pad_character, pad_length) else "")
        output.push (if match[5] then arg + pad else pad + arg)
      i++
    output.join ""

  str_format.cache = {}
  str_format.parse = (fmt) ->
    _fmt = fmt
    match = []
    parse_tree = []
    arg_names = 0
    while _fmt
      if (match = /^[^\x25]+/.exec(_fmt)) isnt null
        parse_tree.push match[0]
      else if (match = /^\x25{2}/.exec(_fmt)) isnt null
        parse_tree.push "%"
      else if (match = /^\x25(?:([1-9]\d*)\$|\(([^\)]+)\))?(\+)?(0|'[^$])?(-)?(\d+)?(?:\.(\d+))?([b-fosOuxX])/.exec(_fmt)) isnt null
        if match[2]
          arg_names |= 1
          field_list = []
          replacement_field = match[2]
          field_match = []
          if (field_match = /^([a-z_][a-z_\d]*)/i.exec(replacement_field)) isnt null
            field_list.push field_match[1]
            while (replacement_field = replacement_field.substring(field_match[0].length)) isnt ""
              if (field_match = /^\.([a-z_][a-z_\d]*)/i.exec(replacement_field)) isnt null
                field_list.push field_match[1]
              else if (field_match = /^\[(\d+)\]/.exec(replacement_field)) isnt null
                field_list.push field_match[1]
              else
                throw ("[sprintf] huh?")
          else
            throw ("[sprintf] huh?")
          match[2] = field_list
        else
          arg_names |= 2
        throw ("[sprintf] mixing positional and named placeholders is not (yet) supported")  if arg_names is 3
        parse_tree.push match
      else
        throw ("[sprintf] huh?")
      _fmt = _fmt.substring(match[0].length)
    parse_tree

  str_format
)()
vsprintf = (fmt, argv) ->
  argv.unshift fmt
  sprintf.apply null, argv

exports.sprintf = sprintf
exports.vsprintf = vsprintf