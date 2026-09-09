///|
fn parse_param(arg : String, params : Map[String, Json]) -> Bool {
  guard arg.split_once("=") is Some((key, raw)) &&
    key.to_owned().split_once(".") is Some((plugin, name)) &&
    !plugin.is_empty() &&
    !name.is_empty() else {
    return false
  }
  let value : Json = if raw == "true" {
    true
  } else if raw == "false" {
    false
  } else {
    let integer = try @string.parse_int(raw.to_owned()) catch {
      _ => None
    } noraise {
      n => Some(n)
    }
    match integer {
      Some(n) => n.to_json()
      None =>
        if raw.contains(",") {
          Json::array(
            raw.split(",").map(s => Json::string(s.to_owned())).to_array(),
          )
        } else {
          Json::string(raw.to_owned())
        }
    }
  }
  let obj = match params.get(plugin.to_owned()) {
    Some(Object(obj)) => obj
    _ => Map([])
  }
  obj[name.to_owned()] = value
  params[plugin.to_owned()] = Json::object(obj)
  true
}
