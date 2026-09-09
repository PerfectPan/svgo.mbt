///|
/// What to run and how to print: the plugin list in execution order,
/// numeric precision, multipass and pretty printing. Start from
/// `Config::default()` and override fields with record update syntax.
pub(all) struct Config {
  /// names of plugins to run, in order; defaults to the preset
  plugins : Array[String]
  /// per-plugin JSON parameter objects, keyed by plugin name
  params : Map[String, Json]
  /// decimal places kept for numbers
  precision : Int
  /// repeat the pipeline until nothing changes (at most 10 passes)
  multipass : Bool
  /// indent the output
  pretty : Bool
} derive(Debug)

///|
/// svgo's preset-default plugins in svgo's order (except the opt-in
/// `moveGroupAttrsToElems`), 3 decimal places, multipass on, compact output.
pub fn Config::default() -> Config {
  {
    plugins: @plugins.preset_default.map(p => p.name),
    params: Map([]),
    precision: 3,
    multipass: true,
    pretty: false,
  }
}

///|
/// Outcome of `optimize`: the optimized document plus size statistics and
/// the list of plugins that changed something.
pub(all) struct Result {
  data : String
  /// UTF-8 byte sizes before and after
  original_size : Int
  size : Int
  passes : Int
  /// plugins that changed the document at least once
  applied : Array[String]
} derive(Debug)

///|
/// Bytes saved as a percentage of the original size (0 for an empty input).
pub fn Result::saved_percent(self : Result) -> Double {
  if self.original_size == 0 {
    0.0
  } else {
    (self.original_size - self.size).to_double() *
    100.0 /
    self.original_size.to_double()
  }
}

///|
/// Raised by `optimize` when `Config::plugins` names a plugin that does not exist.
pub suberror UnknownPlugin {
  UnknownPlugin(String)
} derive(Debug)

///|
pub impl Show for UnknownPlugin with fn output(self, logger) {
  match self {
    UnknownPlugin(n) => logger.write_string("unknown plugin '\{n}'")
  }
}

///|
/// Optimize an SVG document.
pub fn optimize(
  svg : String,
  config? : Config = Config::default(),
) -> Result raise {
  let doc = @xml.parse(svg)
  let plugins : Array[@plugins.Plugin] = []
  for name in config.plugins {
    match @plugins.find_plugin(name) {
      Some(p) => plugins.push(p)
      None => raise UnknownPlugin(name)
    }
  }
  let ctx = @plugins.Context::new(precision=config.precision)
  let applied : Set[String] = Set([])
  let mut passes = 0
  for ;; {
    passes += 1
    let mut changed = false
    for p in plugins {
      ctx.set_params(config.params.get(p.name).unwrap_or(Json::object(Map([]))))
      if (p.run)(doc, ctx) {
        changed = true
        applied.add(p.name)
      }
    }
    if !changed || !config.multipass || passes >= 10 {
      break
    }
  }
  let data = doc.to_string(options={ pretty: config.pretty, prolog: true, })
  {
    data,
    original_size: utf8_length(svg),
    size: utf8_length(data),
    passes,
    applied: applied.iter().to_array(),
  }
}

///|
/// Names of all available plugins with their descriptions.
pub fn list_plugins() -> Array[(String, String, Bool)] {
  let out = []
  for p in @plugins.preset_default {
    out.push((p.name, p.description, true))
  }
  for p in @plugins.optional_plugins {
    out.push((p.name, p.description, false))
  }
  out
}

///|
/// Number of bytes of the UTF-8 encoding of `s`, without encoding it.
pub fn utf8_length(s : String) -> Int {
  let mut n = 0
  for c in s.code_units() {
    let u = c.to_int()
    n += if u < 0x80 {
      1
    } else if u < 0x800 {
      2
    } else if u >= 0xD800 && u <= 0xDBFF {
      4 // high surrogate: the pair encodes to four bytes, low one adds nothing
    } else if u >= 0xDC00 && u <= 0xDFFF {
      0
    } else {
      3
    }
  }
  n
}
