///|
/// Specificity calculation for CSS selectors according to Selectors Level 3/4.

///|
/// Calculate specificity for a compound selector.
pub fn compound_specificity(compound : CompoundSelector) -> Specificity {
  let mut b = 0
  let mut c = 0
  let mut d = 0
  for simple in compound.simples {
    match simple {
      Universal => ()
      Type(_) => d += 1
      PseudoElement(_) => d += 1
      Id(_) => b += 1
      Class(_) => c += 1
      Attribute(_, _) => c += 1
      PseudoClass(name, arg) =>
        // :not(s) takes specificity of its argument
        if name == "not" || name == "is" || name == "has" {
          if arg is Some(inner) {
            let inner_spec = selector_list_max_specificity(inner)
            b += inner_spec.b
            c += inner_spec.c
            d += inner_spec.d
          }
        } else if name == "where" {
          // :where has 0 specificity
          ()
        } else {
          c += 1
        }
    }
  }
  { a: 0, b, c, d, }
}

///|
/// Calculate specificity for a complex selector.
pub fn complex_specificity(complex : ComplexSelector) -> Specificity {
  let mut spec = compound_specificity(complex.head)
  for pair in complex.tail {
    let (_, compound) = pair
    spec = spec.add(compound_specificity(compound))
  }
  spec
}

///|
pub fn ComplexSelector::specificity(self : ComplexSelector) -> Specificity {
  complex_specificity(self)
}

///|
/// Specificity of a selector list string, returning max specificity.
fn selector_list_max_specificity(s : String) -> Specificity {
  match parse_complex_selector(s) {
    Some(complex) => complex_specificity(complex)
    None => { a: 0, b: 0, c: 0, d: 0, }
  }
}
