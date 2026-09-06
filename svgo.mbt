///|
pub(all) struct Config {
  /// names of plugins to run, in order; defaults to the preset
  plugins : Array[String]
  /// decimal places kept for numbers
  precision : Int
  /// repeat the pipeline until nothing changes (at most 10 passes)
  multipass : Bool
  /// indent the output
  pretty : Bool
} derive(Debug)

///|
pub fn Config::default() -> Config {
  {
    plugins: @plugins.preset_default.map(p => p.name),
    precision: 3,
    multipass: true,
    pretty: false,
  }
}

///|
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
  let ctx : @plugins.Context = { precision: config.precision, }
  let applied : Set[String] = Set([])
  let mut passes = 0
  for ;; {
    passes += 1
    let mut changed = false
    for p in plugins {
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
    original_size: @utf8.encode(svg).length(),
    size: @utf8.encode(data).length(),
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
