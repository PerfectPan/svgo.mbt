///|
/// Host-facing entry point.
///
/// Arguments and results cross the boundary as one flat string of
/// length-prefixed tokens, `<length>:<text>` with the length in UTF-16 code
/// units, so the module carries neither a JSON parser nor a printer.
/// `index.mjs` speaks the same format; it is the only consumer. The config
/// layout is documented on `read_config`, the result layout on `optimize_wire`.
///
/// Result tokens: `ok`, originalSize, size, passes, appliedCount, the applied
/// plugin names, data. Or: `err`, message.
#export_name("optimize")
pub fn optimize_wire(svg : String, config : String) -> String {
  let cfg = read_config(config) catch {
    e => return error_wire("invalid config: \{e}")
  }
  let result = @svgo.optimize(svg, config=cfg) catch {
    e => return error_wire(e.to_string())
  }
  let w = Writer::new()
  w.token("ok")
  w.token(result.original_size.to_string())
  w.token(result.size.to_string())
  w.token(result.passes.to_string())
  w.token(result.applied.length().to_string())
  for name in result.applied {
    w.token(name)
  }
  w.token(result.data)
  w.finish()
}

///|
fn error_wire(msg : String) -> String {
  let w = Writer::new()
  w.token("err")
  w.token(msg)
  w.finish()
}

///|
/// Plugin catalogue: count, then name, description and `1`/`0` per plugin.
#export_name("plugins")
pub fn plugins_wire() -> String {
  let items = @svgo.list_plugins()
  let w = Writer::new()
  w.token(items.length().to_string())
  for p in items {
    let (name, desc, on) = p
    w.token(name)
    w.token(desc)
    w.token(if on { "1" } else { "0" })
  }
  w.finish()
}

///|
/// Library version, matching moon.mod.
#export_name("version")
pub fn version() -> String {
  "0.1.3"
}

///|
/// Config tokens, in order:
///   precision   integer text, or empty for the default
///   multipass   `0` or `1`, empty for the default
///   pretty      `0` or `1`, empty for the default
///   plugins     count followed by that many names; empty count for the preset
///   params      count of plugins with parameters, then per plugin its name and
///               one value (see `read_value`)
fn read_config(text : String) -> @svgo.Config raise WireError {
  let base = @svgo.Config::default()
  let r = Reader::new(text)
  let precision = match r.next() {
    "" => base.precision
    t => int_of(t)
  }
  let multipass = r.next() != "0"
  let pretty = r.next() == "1"
  let plugins = match r.next() {
    "" => base.plugins
    t => {
      let out = []
      for _ in 0..<int_of(t) {
        out.push(r.next())
      }
      out
    }
  }
  let params : Map[String, Json] = Map([])
  for _ in 0..<int_of(r.next()) {
    let name = r.next()
    params[name] = r.read_value()
  }
  { plugins, params, precision, multipass, pretty, }
}

///|
priv suberror WireError {
  WireError(String)
}

///|
impl Show for WireError with fn output(self, logger) {
  match self {
    WireError(msg) => logger.write_string(msg)
  }
}

///|
priv struct Reader {
  cu : ArrayView[UInt16]
  text : String
  mut pos : Int
}

///|
fn Reader::new(text : String) -> Reader {
  { cu: text.code_units(), text, pos: 0, }
}

///|
fn Reader::next(self : Reader) -> String raise WireError {
  let n = self.cu.length()
  let mut i = self.pos
  let mut len = 0
  let mut digits = 0
  while i < n && self.cu[i] >= 48 && self.cu[i] <= 57 {
    len = len * 10 + (self.cu[i].to_int() - 48)
    digits += 1
    i += 1
  }
  guard digits > 0 && i < n && self.cu[i] == 58 && i + 1 + len <= n else {
    raise WireError("malformed token at \{self.pos}")
  }
  self.pos = i + 1 + len
  self.text[i + 1:self.pos].to_owned()
}

///|
fn int_of(t : String) -> Int raise WireError {
  match @num.parse_number(t) {
    Some(v) => v.to_int()
    None => raise WireError("expected a number, got '\{t}'")
  }
}

///|
/// A JSON value as the encoder writes it: `b0`/`b1`, `z` (null), `n<text>`,
/// `s<text>`, `a<count>` followed by the items, `o<count>` followed by
/// key/value pairs. The tag is the first code unit of the token.
fn Reader::read_value(self : Reader) -> Json raise WireError {
  let t = self.next()
  let rest = t[1:].to_owned()
  match t.get_char(0) {
    Some('b') => Json::boolean(rest == "1")
    Some('z') => Json::null()
    Some('n') => Json::number(double_of(rest))
    Some('s') => Json::string(rest)
    Some('a') => {
      let items = []
      for _ in 0..<int_of(rest) {
        items.push(self.read_value())
      }
      Json::array(items)
    }
    Some('o') => {
      let obj : Map[String, Json] = Map([])
      for _ in 0..<int_of(rest) {
        let key = self.next()
        obj[key] = self.read_value()
      }
      Json::object(obj)
    }
    _ => raise WireError("unknown value tag '\{t}'")
  }
}

///|
fn double_of(t : String) -> Double raise WireError {
  match @num.parse_number(t) {
    Some(v) => v
    None => raise WireError("expected a number, got '\{t}'")
  }
}

///|
priv struct Writer {
  sb : StringBuilder
}

///|
fn Writer::new() -> Writer {
  { sb: StringBuilder(), }
}

///|
fn Writer::token(self : Writer, s : String) -> Unit {
  self.sb.write_string(s.length().to_string())
  self.sb.write_char(':')
  self.sb.write_string(s)
}

///|
fn Writer::finish(self : Writer) -> String {
  self.sb.to_string()
}
