///|
/// Interface language. The root component keeps the choice in its model and
/// mirrors it into `lang` before rendering, so views can call `t` without
/// threading it through every function. `t` picks a string, `tm` markup.
pub(all) enum Lang {
  En
  Zh
} derive(Eq)

///|
pub let lang : Ref[Lang] = { val: En, }

///|
/// Pick the string for the current language.
pub fn t(en : String, zh : String) -> String {
  match lang.val {
    En => en
    Zh => zh
  }
}

///|
/// Same, for markup.
pub fn tm(en : Array[Html], zh : Array[Html]) -> Array[Html] {
  match lang.val {
    En => en
    Zh => zh
  }
}

///|
pub fn Lang::code(self : Lang) -> String {
  match self {
    En => "en"
    Zh => "zh"
  }
}

///|
pub fn Lang::parse(s : String) -> Lang? {
  match s {
    "en" => Some(En)
    "zh" => Some(Zh)
    _ => None
  }
}
