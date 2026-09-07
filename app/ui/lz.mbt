///|
/// A port of lz-string's URI-safe variant (`compressToEncodedURIComponent`),
/// used for share links the same way the TypeScript playground does: the
/// document goes into the URL hash as a short, link-safe string instead of
/// base64 of the raw text. Works on UTF-16 code units, like the original.
let lz_alphabet : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-$"

///|
let lz_reverse : Map[Int, Int] = {
  let m : Map[Int, Int] = Map([])
  for i, u in lz_alphabet.code_units() {
    m[u.to_int()] = i
  }
  m
}

///|
priv struct BitWriter {
  out : StringBuilder
  mut val : Int
  mut position : Int
}

///|
fn BitWriter::push(self : BitWriter, bit : Int) -> Unit {
  self.val = (self.val << 1) | bit
  if self.position == 5 {
    self.position = 0
    self.out.write_char(lz_alphabet.get_char(self.val).unwrap())
    self.val = 0
  } else {
    self.position += 1
  }
}

///|
fn BitWriter::push_bits(self : BitWriter, value : Int, count : Int) -> Unit {
  let mut v = value
  for _ in 0..<count {
    self.push(v & 1)
    v = v >> 1
  }
}

///|
/// One UTF-16 code unit as a string. Lone surrogates cannot be built from a
/// `Char`, so characters outside the BMP come back as U+FFFD after a
/// roundtrip; SVG sources practically never contain them.
fn unit_string(code : Int) -> String {
  String::from_array([code.to_char().unwrap_or('\u{FFFD}')])
}

///|
fn unit_at(s : String, i : Int) -> Int {
  s.code_units()[i].to_int()
}

///|
/// Compress `input` to a string made only of `A-Za-z0-9+-$`.
pub fn lz_compress(input : String) -> String {
  if input.is_empty() {
    return ""
  }
  let dict : Map[String, Int] = Map([])
  let to_create : Set[String] = Set([])
  let w = BitWriter::{ out: StringBuilder(), val: 0, position: 0, }
  let mut current = ""
  let mut enlarge_in = 2
  let mut dict_size = 3
  let mut num_bits = 2
  let emit_word = fn(word : String) {
    if to_create.contains(word) {
      let code = unit_at(word, 0)
      if code < 256 {
        w.push_bits(0, num_bits)
        w.push_bits(code, 8)
      } else {
        w.push_bits(1, num_bits)
        w.push_bits(code, 16)
      }
      enlarge_in -= 1
      if enlarge_in == 0 {
        enlarge_in = 1 << num_bits
        num_bits += 1
      }
      to_create.remove(word)
    } else {
      w.push_bits(dict.get(word).unwrap_or(0), num_bits)
    }
    enlarge_in -= 1
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
  }
  for i in 0..<input.length() {
    let c = input.unsafe_substring(start=i, end=i + 1)
    if !dict.contains(c) {
      dict[c] = dict_size
      dict_size += 1
      to_create.add(c)
    }
    let wc = current + c
    if dict.contains(wc) {
      current = wc
    } else {
      emit_word(current)
      dict[wc] = dict_size
      dict_size += 1
      current = c
    }
  }
  if !current.is_empty() {
    emit_word(current)
  }
  // end of stream marker
  w.push_bits(2, num_bits)
  while true {
    w.val = w.val << 1
    if w.position == 5 {
      w.out.write_char(lz_alphabet.get_char(w.val).unwrap())
      break
    }
    w.position += 1
  }
  w.out.to_string()
}

///|
priv struct BitReader {
  input : String
  mut val : Int
  mut position : Int
  mut index : Int
}

///|
fn BitReader::next_value(self : BitReader) -> Int {
  let i = self.index
  self.index += 1
  if i < self.input.length() {
    lz_reverse.get(unit_at(self.input, i)).unwrap_or(0)
  } else {
    0
  }
}

///|
fn BitReader::read_bits(self : BitReader, count : Int) -> Int {
  let mut bits = 0
  let mut power = 1
  for _ in 0..<count {
    let resb = self.val & self.position
    self.position = self.position >> 1
    if self.position == 0 {
      self.position = 32
      self.val = self.next_value()
    }
    if resb > 0 {
      bits = bits | power
    }
    power = power << 1
  }
  bits
}

///|
/// Inverse of `lz_compress`. Returns `None` for malformed input.
pub fn lz_decompress(input : String) -> String? {
  if input.is_empty() {
    return Some("")
  }
  let input = input.replace_all(old=" ", new="+")
  let r = BitReader::{ input, val: 0, position: 32, index: 0, }
  r.val = r.next_value()
  let dictionary : Array[String] = ["", "", ""]
  let mut enlarge_in = 4
  let mut dict_size = 4
  let mut num_bits = 3
  let first = match r.read_bits(2) {
    0 => unit_string(r.read_bits(8))
    1 => unit_string(r.read_bits(16))
    _ => return Some("")
  }
  dictionary.push(first)
  let mut w = first
  let out = StringBuilder()
  out.write_string(first)
  while true {
    if r.index > input.length() {
      return None
    }
    let mut c = r.read_bits(num_bits)
    match c {
      0 => {
        dictionary.push(unit_string(r.read_bits(8)))
        c = dict_size
        dict_size += 1
        enlarge_in -= 1
      }
      1 => {
        dictionary.push(unit_string(r.read_bits(16)))
        c = dict_size
        dict_size += 1
        enlarge_in -= 1
      }
      2 => return Some(out.to_string())
      _ => ()
    }
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
    let entry = if c < dictionary.length() {
      dictionary[c]
    } else if c == dict_size {
      w + w.unsafe_substring(start=0, end=1)
    } else {
      return None
    }
    out.write_string(entry)
    dictionary.push(w + entry.unsafe_substring(start=0, end=1))
    dict_size += 1
    enlarge_in -= 1
    w = entry
    if enlarge_in == 0 {
      enlarge_in = 1 << num_bits
      num_bits += 1
    }
  }
  None
}
