///|
/// CSS AST types and specificity representation.
pub(all) struct Specificity {
  a : Int // inline style (1 or 0)
  b : Int // IDs
  c : Int // classes, attributes, pseudo-classes
  d : Int // type (tag) selectors, pseudo-elements
} derive(Eq, Compare, Debug)

///|
pub impl Show for Specificity with fn output(self, logger) {
  logger.write_string("Specificity(")
  logger.write_string(self.a.to_string())
  logger.write_string(",")
  logger.write_string(self.b.to_string())
  logger.write_string(",")
  logger.write_string(self.c.to_string())
  logger.write_string(",")
  logger.write_string(self.d.to_string())
  logger.write_string(")")
}

///|
pub fn Specificity::new(a : Int, b : Int, c : Int, d : Int) -> Specificity {
  { a, b, c, d, }
}

///|
pub fn Specificity::compare(self : Specificity, other : Specificity) -> Int {
  if self.a != other.a {
    return self.a - other.a
  }
  if self.b != other.b {
    return self.b - other.b
  }
  if self.c != other.c {
    return self.c - other.c
  }
  self.d - other.d
}

///|
pub fn Specificity::add(self : Specificity, other : Specificity) -> Specificity {
  {
    a: self.a + other.a,
    b: self.b + other.b,
    c: self.c + other.c,
    d: self.d + other.d,
  }
}

///|
pub(all) struct Declaration {
  name : String
  value : String
  important : Bool
} derive(Eq, Debug)

///|
pub(all) enum Combinator {
  Descendant // space
  Child // >
  NextSibling // +
  SubsequentSibling // ~
  Deep // /deep/
} derive(Eq, Debug)

///|
pub(all) enum AttrMatcher {
  Exists // [attr]
  Equals(String) // [attr=val]
  Includes(String) // [attr~=val]
  DashMatch(String) // [attr|=val]
  PrefixMatch(String) // [attr^=val]
  SuffixMatch(String) // [attr$=val]
  SubstringMatch(String) // [attr*=val]
} derive(Eq, Debug)

///|
pub(all) enum SimpleSelector {
  Universal
  Type(String)
  Id(String)
  Class(String)
  Attribute(String, AttrMatcher)
  PseudoClass(String, String?) // e.g. :hover, :not(...)
  PseudoElement(String) // e.g. ::before
} derive(Eq, Debug)

///|
pub(all) struct CompoundSelector {
  simples : Array[SimpleSelector]
} derive(Eq, Debug)

///|
pub(all) struct ComplexSelector {
  head : CompoundSelector
  tail : Array[(Combinator, CompoundSelector)]
  raw : String
} derive(Eq, Debug)

///|
pub(all) struct Rule {
  selectors : Array[ComplexSelector]
  declarations : Array[Declaration]
} derive(Debug)

///|
pub(all) enum StyleSheetItem {
  Rule(Rule)
  Declarations(Array[Declaration]) // declaration block inside @font-face, @viewport, @page, etc.
  AtRule(String, String, Array[StyleSheetItem]?) // name, params, block (if any)
  Raw(String)
} derive(Debug)

///|
pub(all) struct StyleSheet {
  items : Array[StyleSheetItem]
} derive(Debug)
