///|
const SKETCH =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<svg width="24px" height="24px" viewBox="0 0 24 24" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  #|    <!-- Generator: Sketch 60.1 (88133) - https://sketch.com -->
  #|    <title>icon/action/close</title>
  #|    <desc>Created with Sketch.</desc>
  #|    <g id="icon/action/close" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
  #|        <g id="Group" transform="translate(2.000000, 2.000000)" fill="#FF0000" fill-rule="nonzero">
  #|            <path d="M 4.000000,4.000000 L 16.000000,16.000000 M 16.000000,4.000000 L 4.000000,16.000000" id="Shape" stroke="#FF0000" stroke-width="2.000000" stroke-linecap="round"></path>
  #|            <rect id="Rectangle" fill-opacity="1" x="0" y="0" width="20" height="20" rx="0"></rect>
  #|        </g>
  #|    </g>
  #|</svg>

///|
test "sketch export" {
  let r = @svgo.optimize(SKETCH)
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><title>icon/action/close</title><g fill="red" transform="translate(2 2)"><path stroke="red" stroke-linecap="round" stroke-width="2" d="m4 4 12 12m0-12L4 16"/><path d="M0 0h20v20H0z"/></g></svg>
    ),
  )
  inspect(r.saved_percent() > 60.0, content="true")
}

///|
test "colors, numbers and defaults" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10.000 10.000"><rect x="0.0" y="0px" width="10.123456" height="5" fill="rgb(255, 0, 0)" stroke="#00FF00" stroke-width="1" opacity="1" fill-opacity="0.5"/><circle cx="5" cy="5" r="2" fill="BLACK" stroke="#ABCDEF"/></svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><path fill="red" fill-opacity=".5" stroke="#0f0" d="M0 0h10.123v5H0z"/><circle cx="5" cy="5" r="2" stroke="#abcdef"/></svg>
    ),
  )
}

///|
test "inherited defaults are kept when an ancestor overrides them" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg"><g stroke-width="3" stroke="blue"><path stroke-width="1" d="M0 0L5 5"/><path stroke="none" d="M0 0L6 6"/></g></svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg"><g stroke="#00f" stroke-width="3"><path stroke-width="1" d="m0 0 5 5"/><path stroke="none" d="m0 0 6 6"/></g></svg>
    ),
  )
}

///|
test "hidden elements, empty containers, unused ids and defs" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
      #|  <defs><linearGradient id="unused"/><linearGradient id="used"><stop offset="0"/></linearGradient><g><path id="p" d="M0 0h1"/></g></defs>
      #|  <g id="layer"><g></g><rect width="0" height="10"/><path d="" /><text></text></g>
      #|  <rect width="10" height="10" fill="url(#used)"/>
      #|  <use xlink:href="#p"/>
      #|  <g display="none"><circle r="5"/></g>
      #|</svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><defs><linearGradient id="used"><stop offset="0"/></linearGradient><path id="p" d="M0 0h1"/></defs><path fill="url(#used)" d="M0 0h10v10H0z"/><use xlink:href="#p"/></svg>
    ),
  )
}

///|
test "groups collapse and paths merge only when safe" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg"><g><g fill="red"><path d="M0 0h10v10H0z"/></g></g><path fill="blue" d="M20 0h10v10H20z"/><path fill="blue" d="M40 0h10v10H40z"/><path fill="blue" d="M45 0h10v10H45z"/></svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg"><path fill="red" d="M0 0h10v10H0z"/><path fill="#00f" d="M20 0h10v10H20zm20 0h10v10H40z"/><path fill="#00f" d="M45 0h10v10H45z"/></svg>
    ),
  )
}

///|
test "shapes to paths, ellipse to circle, editor namespaces" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" inkscape:version="1.2">
      #|  <inkscape:grid/>
      #|  <line x1="0" y1="0" x2="10" y2="10" stroke="black" inkscape:label="l"/>
      #|  <polygon points="0,0 10,0 10,10" fill="#333333"/>
      #|  <ellipse cx="5" cy="5" rx="3" ry="3"/>
      #|  <rect x="1" y="1" width="50%" height="4"/>
      #|</svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg"><path stroke="#000" d="m0 0 10 10"/><path fill="#333" d="M0 0h10v10z"/><circle cx="5" cy="5" r="3"/><rect width="50%" height="4" x="1" y="1"/></svg>
    ),
  )
}

///|
test "legal comments, text whitespace and style attributes survive" {
  let r = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg"><!--! (c) 2026 --><!-- noise --><text x="1" y="2">  a   b </text><path style="fill:#FF0000;stroke:none" d="M0 0 1 1"/></svg>
    ),
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg"><!--! (c) 2026 --><text x="1" y="2">  a   b </text><path d="m0 0 1 1" style="fill:red;stroke:none"/></svg>
    ),
  )
}

///|
test "custom config" {
  let r = @svgo.optimize(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\" viewBox=\"0 0 10 10\"><title>t</title><path d=\"M0.12345 0L5 5\"/></svg>",
    config={
      ..@svgo.Config::default(),
      plugins: ["removeTitle", "removeDimensions", "convertPathData"],
      precision: 1,
      pretty: true,
    },
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
      #|  <path d="M.1 0 5 5"/>
      #|</svg>
      #|
    ),
  )
  try
    @svgo.optimize("<svg/>", config={
      ..@svgo.Config::default(),
      plugins: ["nope"],
    })
  catch {
    e => inspect(e, content="unknown plugin 'nope'")
  } noraise {
    _ => fail("expected error")
  }
}
