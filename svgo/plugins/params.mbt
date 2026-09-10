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
fn Context::has_param(self : Context, name : String) -> Bool {
  self.param(name) is Some(_)
}

///|
/// Read a boolean, falling back for absent or incorrectly typed values.
fn Context::param_bool(self : Context, name : String, default : Bool) -> Bool {
  match self.param(name) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
/// Read an integer parameter, falling back for absent or incorrectly typed values.
fn Context::param_int(self : Context, name : String, default : Int) -> Int {
  match self.param(name) {
    Some(Number(n, ..)) => n.to_int()
    _ => default
  }
}

///|
/// Read a string parameter, falling back for absent or incorrectly typed values.
fn Context::param_string(
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
fn Context::param_strings(self : Context, name : String) -> Array[String] {
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

///|
test "typed params accept strings and arrays and fall back on wrong types" {
  let ctx = Context::new()
  ctx.set_params({
    "bool": false,
    "int": 2,
    "one": "a",
    "many": ["a", 7, "b"],
    "empty": [],
  })
  assert_eq(ctx.param_bool("bool", true), false)
  assert_eq(ctx.param_bool("one", true), true)
  assert_eq(ctx.param_int("int", 3), 2)
  assert_eq(ctx.param_int("one", 3), 3)
  assert_eq(ctx.param_string("int", "fallback"), "fallback")
  assert_eq(ctx.param_strings("one"), ["a"])
  assert_eq(ctx.param_strings("many"), ["a", "b"])
  assert_true(ctx.has_param("empty"))
  ctx.set_params(Json::null())
  assert_false(ctx.has_param("empty"))
  assert_eq(ctx.param_strings("many"), [])
}
