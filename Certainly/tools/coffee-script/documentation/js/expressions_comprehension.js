var globals, name;

globals = ((function() {
  var _results;
  _results = [];
  for (name in window) {
    _results.push(name);
  }
  return _results;
})()).slice(0, 10);
