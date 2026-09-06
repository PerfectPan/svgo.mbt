///|
/// Host-facing entry point. `config_json` is a JSON object with optional
/// keys `plugins` (array of names), `precision`, `multipass`, `pretty`.
/// Returns a JSON object: `{ data, originalSize, size, passes, applied }`
/// or `{ error }`.
#export_name("optimize")
pub fn optimize_json(svg : String, config_json : String) -> String {
  let base = @svgo.Config::default()
  let config : @svgo.Config = try {
    let j = if config_json.trim().is_empty() {
      Json::object(Map([]))
    } else {
      @json.parse(config_json)
    }
    let field = fn(key : String) -> Json? {
      if j is Object(obj) {
        obj.get(key)
      } else {
        None
      }
    }
    let plugins = match field("plugins") {
      Some(Array(items)) =>
        items.filter_map(v => if v is String(s) { Some(s) } else { None })
      _ => base.plugins
    }
    let precision = match field("precision") {
      Some(Number(n, ..)) => n.to_int()
      _ => base.precision
    }
    let multipass = match field("multipass") {
      Some(False) => false
      _ => true
    }
    let pretty = match field("pretty") {
      Some(True) => true
      _ => false
    }
    { plugins, precision, multipass, pretty, }
  } catch {
    e => return error_json("invalid config: \{e}")
  }
  let result = @svgo.optimize(svg, config~) catch {
    e => return error_json(e.to_string())
  }
  let obj : Json = {
    "data": result.data,
    "originalSize": result.original_size,
    "size": result.size,
    "passes": result.passes,
    "applied": result.applied.map(s => Json::string(s)),
  }
  obj.stringify()
}

///|
fn error_json(msg : String) -> String {
  let obj : Json = { "error": msg }
  obj.stringify()
}

///|
/// Plugin catalogue as JSON: `[{ name, description, enabled }]`.
#export_name("plugins")
pub fn plugins_json() -> String {
  let items : Array[Json] = []
  for p in @svgo.list_plugins() {
    let (name, desc, on) = p
    items.push({ "name": name, "description": desc, "enabled": on })
  }
  Json::array(items).stringify()
}

///|
#export_name("version")
pub fn version() -> String {
  "0.1.0"
}
