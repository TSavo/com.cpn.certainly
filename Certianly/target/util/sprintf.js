(function() {
  var sprintf, util, vsprintf;

  util = require("util");

  sprintf = (function() {
    var get_type, str_format, str_repeat;
    get_type = function(variable) {
      return Object.prototype.toString.call(variable).slice(8, -1).toLowerCase();
    };
    str_repeat = function(input, multiplier) {
      var output;
      output = [];
      while (multiplier > 0) {
        output[--multiplier] = input;
      }
      return output.join("");
    };
    str_format = function() {
      if (!str_format.cache.hasOwnProperty(arguments[0])) {
        str_format.cache[arguments[0]] = str_format.parse(arguments[0]);
      }
      return str_format.format.call(null, str_format.cache[arguments[0]], arguments);
    };
    str_format.format = function(parse_tree, argv) {
      var arg, cursor, i, k, match, node_type, output, pad, pad_character, pad_length, tree_length;
      cursor = 1;
      tree_length = parse_tree.length;
      node_type = "";
      arg = void 0;
      output = [];
      i = void 0;
      k = void 0;
      match = void 0;
      pad = void 0;
      pad_character = void 0;
      pad_length = void 0;
      i = 0;
      while (i < tree_length) {
        node_type = get_type(parse_tree[i]);
        if (node_type === "string") {
          output.push(parse_tree[i]);
        } else if (node_type === "array") {
          match = parse_tree[i];
          if (match[2]) {
            arg = argv[cursor];
            k = 0;
            while (k < match[2].length) {
              if (!arg.hasOwnProperty(match[2][k])) {
                throw sprintf("[sprintf] property \"%s\" does not exist", match[2][k]);
              }
              arg = arg[match[2][k]];
              k++;
            }
          } else if (match[1]) {
            arg = argv[match[1]];
          } else {
            arg = argv[cursor++];
          }
          if (/[^sO]/.test(match[8]) && (get_type(arg) !== "number")) {
            throw sprintf("[sprintf] expecting number but found %s", get_type(arg));
          }
          switch (match[8]) {
            case "b":
              arg = arg.toString(2);
              break;
            case "c":
              arg = String.fromCharCode(arg);
              break;
            case "d":
              arg = parseInt(arg, 10);
              break;
            case "e":
              arg = (match[7] ? arg.toExponential(match[7]) : arg.toExponential());
              break;
            case "f":
              arg = (match[7] ? parseFloat(arg).toFixed(match[7]) : parseFloat(arg));
              break;
            case "O":
              arg = util.inspect(arg);
              break;
            case "o":
              arg = arg.toString(8);
              break;
            case "s":
              arg = ((arg = String(arg)) && match[7] ? arg.substring(0, match[7]) : arg);
              break;
            case "u":
              arg = Math.abs(arg);
              break;
            case "x":
              arg = arg.toString(16);
              break;
            case "X":
              arg = arg.toString(16).toUpperCase();
          }
          arg = (/[def]/.test(match[8]) && match[3] && arg >= 0 ? "+" + arg : arg);
          pad_character = (match[4] ? (match[4] === "0" ? "0" : match[4].charAt(1)) : " ");
          pad_length = match[6] - String(arg).length;
          pad = (match[6] ? str_repeat(pad_character, pad_length) : "");
          output.push((match[5] ? arg + pad : pad + arg));
        }
        i++;
      }
      return output.join("");
    };
    str_format.cache = {};
    str_format.parse = function(fmt) {
      var arg_names, field_list, field_match, match, parse_tree, replacement_field, _fmt;
      _fmt = fmt;
      match = [];
      parse_tree = [];
      arg_names = 0;
      while (_fmt) {
        if ((match = /^[^\x25]+/.exec(_fmt)) !== null) {
          parse_tree.push(match[0]);
        } else if ((match = /^\x25{2}/.exec(_fmt)) !== null) {
          parse_tree.push("%");
        } else if ((match = /^\x25(?:([1-9]\d*)\$|\(([^\)]+)\))?(\+)?(0|'[^$])?(-)?(\d+)?(?:\.(\d+))?([b-fosOuxX])/.exec(_fmt)) !== null) {
          if (match[2]) {
            arg_names |= 1;
            field_list = [];
            replacement_field = match[2];
            field_match = [];
            if ((field_match = /^([a-z_][a-z_\d]*)/i.exec(replacement_field)) !== null) {
              field_list.push(field_match[1]);
              while ((replacement_field = replacement_field.substring(field_match[0].length)) !== "") {
                if ((field_match = /^\.([a-z_][a-z_\d]*)/i.exec(replacement_field)) !== null) {
                  field_list.push(field_match[1]);
                } else if ((field_match = /^\[(\d+)\]/.exec(replacement_field)) !== null) {
                  field_list.push(field_match[1]);
                } else {
                  throw "[sprintf] huh?";
                }
              }
            } else {
              throw "[sprintf] huh?";
            }
            match[2] = field_list;
          } else {
            arg_names |= 2;
          }
          if (arg_names === 3) {
            throw "[sprintf] mixing positional and named placeholders is not (yet) supported";
          }
          parse_tree.push(match);
        } else {
          throw "[sprintf] huh?";
        }
        _fmt = _fmt.substring(match[0].length);
      }
      return parse_tree;
    };
    return str_format;
  })();

  vsprintf = function(fmt, argv) {
    argv.unshift(fmt);
    return sprintf.apply(null, argv);
  };

  exports.sprintf = sprintf;

  exports.vsprintf = vsprintf;

}).call(this);
