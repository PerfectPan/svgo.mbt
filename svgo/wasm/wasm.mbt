///|
/// Host-facing entry point. `config_json` is a JSON object with optional
/// keys `plugins` (names or `{name, params}` objects), `params` (plugin name to
/// parameter object), `precision`, `multipass`, `pretty`. Entry params override
/// top-level params for the same plugin.
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
    let params = match field("params") {
      Some(Object(obj)) => obj.copy()
      _ => Map([])
    }
    let plugins = match field("plugins") {
      Some(Array(items)) =>
        items.filter_map(v => {
          match v {
            String(s) => Some(s)
            Object(obj) =>
              match obj.get("name") {
                Some(String(name)) => {
                  if obj.get("params") is Some(value) {
                    params[name] = value
                  }
                  Some(name)
                }
                _ => None
              }
            _ => None
          }
        })
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
    { plugins, params, precision, multipass, pretty, }
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
/// Library version, matching moon.mod.
#export_name("version")
pub fn version() -> String {
  "0.1.0"
}
