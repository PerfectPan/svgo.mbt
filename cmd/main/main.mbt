///|
const USAGE =
  #|svgo.mbt - SVG optimizer written in MoonBit
  #|
  #|usage: svgo <input.svg> [-o <output.svg>] [options]
  #|       svgo --list
  #|
  #|options:
  #|  -o, --output <file>     write the result to a file (default: stdout)
  #|  -p, --precision <n>     decimal places to keep (default 3)
  #|  --pretty                indent the output
  #|  --no-multipass          run the plugin pipeline once
  #|  --disable <plugin>      skip a plugin (repeatable)
  #|  --enable <plugin>       add an optional plugin such as removeDimensions (repeatable)
  #|  --stats                 print size statistics
  #|  --bench <n>             optimize the input n times in-process and report timing

///|
fn cstr(s : String) -> Bytes {
  let buf = Buffer()
  buf.write_bytes(@utf8.encode(s))
  buf.write_byte(b'\x00')
  buf.contents()
}

///|
fn main {
  let args = @env.args()[1:].to_owned()
  if args.length() == 0 || args.contains("-h") || args.contains("--help") {
    println(USAGE)
    return
  }
  if args.contains("--list") {
    for p in @svgo.list_plugins() {
      let (name, desc, on) = p
      println("\{if on { "*" } else { " " }} \{name.pad_end(28, ' ')} \{desc}")
    }
    println("\n* = enabled by default")
    return
  }
  let mut input : String? = None
  let mut output : String? = None
  let mut precision = 3
  let mut pretty = false
  let mut multipass = true
  let mut stats = false
  let mut bench = 0
  let disabled : Array[String] = []
  let enabled : Array[String] = []
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "-o" | "--output" => {
        output = args.get(i + 1)
        i += 1
      }
      "-p" | "--precision" => {
        precision = @string.parse_int(args.get(i + 1).unwrap_or("3")) catch {
          _ => 3
        }
        i += 1
      }
      "--pretty" => pretty = true
      "--no-multipass" => multipass = false
      "--stats" => stats = true
      "--bench" => {
        bench = @string.parse_int(args.get(i + 1).unwrap_or("0")) catch {
          _ => 0
        }
        i += 1
      }
      "--disable" => {
        disabled.push(args.get(i + 1).unwrap_or(""))
        i += 1
      }
      "--enable" => {
        enabled.push(args.get(i + 1).unwrap_or(""))
        i += 1
      }
      a =>
        if a.has_prefix("-") {
          println("unknown option \{a}")
        } else {
          input = Some(a)
        }
    }
    i += 1
  }
  guard input is Some(path) else {
    println(USAGE)
    return
  }
  let bytes = svgo_read_file(cstr(path))
  guard bytes.length() > 0 else {
    println("svgo: cannot read \{path}")
    return
  }
  let source = @utf8.decode_lossy(bytes[:])
  let plugins = @svgo.Config::default().plugins.filter(p => {
    !disabled.contains(p)
  })
  plugins.append(enabled[:])
  if bench > 0 {
    let config : @svgo.Config = { plugins, precision, multipass, pretty, }
    // warm up once, then time the loop (@env.now is milliseconds)
    ignore(@svgo.optimize(source, config~) catch { _ => return })
    let start = @env.now()
    for _ in 0..<bench {
      ignore(@svgo.optimize(source, config~) catch { _ => return })
    }
    let elapsed_ms = (@env.now() - start).to_double()
    let per = (elapsed_ms / bench.to_double() * 1000.0).round() / 1000.0
    println("\{path}: \{bench} runs in \{elapsed_ms} ms, \{per} ms/run")
    return
  }
  let result = @svgo.optimize(source, config={
    plugins,
    precision,
    multipass,
    pretty,
  }) catch {
    e => {
      println("svgo: \{e}")
      return
    }
  }
  match output {
    Some(out) => {
      if svgo_write_file(cstr(out), @utf8.encode(result.data)) != 0 {
        println("svgo: cannot write \{out}")
        return
      }
      if stats {
        report(path, result)
      }
    }
    None => {
      println(result.data)
      if stats {
        report(path, result)
      }
    }
  }
}

///|
fn report(path : String, r : @svgo.Result) -> Unit {
  let pct = (r.saved_percent() * 10.0).round() / 10.0
  println(
    "\{path}: \{r.original_size} -> \{r.size} bytes (-\{pct}%), \{r.passes} pass(es), plugins: \{r.applied.join(", ")}",
  )
}
