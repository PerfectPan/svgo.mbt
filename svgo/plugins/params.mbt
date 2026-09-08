///|
/// Set the current plugin's parameters; non-object values behave as empty objects.
pub fn Context::set_params(self : Context, params : Json) -> Unit {
  self.params = params
}

///|
fn Context::param(self : Context, name : String) -> Json? {
  match self.params {
    Object(obj) => obj.get(name)
    _ => None
  }
}

///|
/// Whether a parameter was supplied, including explicit false or empty arrays.
pub fn Context::has_param(self : Context, name : String) -> Bool {
  self.param(name) is Some(_)
}

///|
/// Read a boolean, falling back for absent or incorrectly typed values.
pub fn Context::param_bool(
  self : Context,
  name : String,
  default : Bool,
) -> Bool {
  match self.param(name) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
/// Read an integer parameter, falling back for absent or incorrectly typed values.
pub fn Context::param_int(self : Context, name : String, default : Int) -> Int {
  match self.param(name) {
    Some(Number(n, ..)) => n.to_int()
    _ => default
  }
}

///|
/// Read a string parameter, falling back for absent or incorrectly typed values.
pub fn Context::param_string(
  self : Context,
  name : String,
  default : String,
) -> String {
  match self.param(name) {
    Some(String(s)) => s
    _ => default
  }
}

///|
/// Read a string or an array of strings; ignore non-string entries.
pub fn Context::param_strings(self : Context, name : String) -> Array[String] {
  match self.param(name) {
    Some(String(s)) => [s]
    Some(Array(items)) =>
      items.filter_map(v => {
        match v {
          String(s) => Some(s)
          _ => None
        }
      })
    _ => []
  }
}
