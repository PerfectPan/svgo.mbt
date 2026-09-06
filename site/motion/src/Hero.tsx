// Hero animation: a verbose editor export is stripped line by line and folds
// into the one-line optimized document, while the byte counter drops.
// Rendered to ../hero.mp4 (see package.json) and played muted in the hero.
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

export const HERO_FPS = 30;
export const HERO_WIDTH = 1280;
export const HERO_HEIGHT = 720;
export const HERO_DURATION = HERO_FPS * 9;

const VIOLET = "#6d5dfc";
const MINT = "#16c79a";
const INK = "#0b0d12";
const MUTED = "#6b7280";
const LINE = "#e9ebf2";

// the Sketch export, one entry per line; `drop` lines disappear, `edit`
// lines are rewritten to their optimized form
type Line = { text: string; kind: "keep" | "drop" | "edit"; to?: string; indent: number };
const INPUT: Line[] = [
  { text: '<?xml version="1.0" encoding="UTF-8"?>', kind: "drop", indent: 0 },
  { text: '<svg width="24px" height="24px" viewBox="0 0 24 24" version="1.1"', kind: "edit", to: '<svg width="24" height="24" viewBox="0 0 24 24"', indent: 0 },
  { text: '     xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">', kind: "edit", to: '     xmlns="http://www.w3.org/2000/svg">', indent: 0 },
  { text: "<!-- Generator: Sketch 60.1 (88133) - https://sketch.com -->", kind: "drop", indent: 1 },
  { text: "<title>icon/action/close</title>", kind: "keep", indent: 1 },
  { text: "<desc>Created with Sketch.</desc>", kind: "drop", indent: 1 },
  { text: '<g id="icon/action/close" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">', kind: "drop", indent: 1 },
  { text: '<g id="Group" transform="translate(2.000000, 2.000000)" fill="#FF0000" fill-rule="nonzero">', kind: "edit", to: '<g fill="red" transform="translate(2 2)">', indent: 2 },
  { text: '<path d="M 4.000000,4.000000 L 16.000000,16.000000 M 16.000000,4.000000 L 4.000000,16.000000"', kind: "edit", to: '<path d="M4 4l12 12M16 4 4 16"', indent: 3 },
  { text: '      id="Shape" stroke="#FF0000" stroke-width="2.000000" stroke-linecap="round"></path>', kind: "edit", to: '      stroke="red" stroke-linecap="round" stroke-width="2"/>', indent: 3 },
  { text: '<rect id="Rectangle" fill-opacity="1" x="0" y="0" width="20" height="20" rx="0"></rect>', kind: "edit", to: '<path d="M0 0h20v20H0z"/>', indent: 3 },
  { text: "</g>", kind: "keep", indent: 2 },
  { text: "</g>", kind: "drop", indent: 1 },
  { text: "</svg>", kind: "keep", indent: 0 },
];

const PLUGINS = ["removeXMLProcInst", "removeComments", "removeDesc", "cleanupNumericValues", "convertColors", "removeUnknownsAndDefaults", "convertShapeToPath", "collapseGroups", "convertPathData", "convertTransform", "removeUnusedNS", "sortAttrs"];

const Icon = ({ size, color }: { size: number; color: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <g fill={color} transform="translate(2 2)">
      <path d="M0 0h20v20H0z" />
      <path d="M4 4l12 12M16 4 4 16" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
    </g>
  </svg>
);

export const Hero = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // timeline (seconds): 0-1 type in, 1-4.5 plugins sweep, 4.5-6 fold, 6-9 hold
  const sweepStart = fps * 1.0;
  const sweepEnd = fps * 4.5;
  const foldStart = fps * 4.8;
  const foldEnd = fps * 6.0;

  // how far the "cursor" of the pipeline has progressed over the lines
  const sweep = interpolate(frame, [sweepStart, sweepEnd], [0, INPUT.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const fold = interpolate(frame, [foldStart, foldEnd], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const appear = spring({ frame, fps, config: { damping: 200 } });

  // byte counter follows the sweep, then settles
  const bytes = Math.round(interpolate(frame, [sweepStart, sweepEnd, foldEnd], [836, 330, 276], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.quad) }));
  const pluginIndex = Math.min(PLUGINS.length - 1, Math.floor(interpolate(frame, [sweepStart, sweepEnd], [0, PLUGINS.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })));
  const showPlugin = frame >= sweepStart && frame < foldStart;

  const lineHeight = 30;
  // vertical position of each surviving line after the fold (drops collapse)
  let survivors = 0;
  const targets = INPUT.map((l) => (l.kind === "drop" ? -1 : survivors++));

  return (
    <AbsoluteFill style={{ background: "#ffffff", fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif", color: INK }}>
      {/* soft colour wash */}
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(600px 400px at 15% 10%, ${VIOLET}22, transparent 60%), radial-gradient(500px 400px at 90% 90%, ${MINT}26, transparent 60%)` }} />

      {/* code card */}
      <div style={{ position: "absolute", left: 72, top: 72, width: 820, height: 576, background: "#fff", border: `1px solid ${LINE}`, borderRadius: 20, boxShadow: "0 30px 80px -40px rgba(30, 20, 90, .35)", overflow: "hidden", opacity: appear, transform: `translateY(${(1 - appear) * 24}px)` }}>
        <div style={{ height: 44, borderBottom: `1px solid ${LINE}`, display: "flex", alignItems: "center", padding: "0 18px", gap: 8, fontSize: 13, color: MUTED }}>
          <span style={{ width: 10, height: 10, borderRadius: 5, background: "#fca5a5" }} />
          <span style={{ width: 10, height: 10, borderRadius: 5, background: "#fcd34d" }} />
          <span style={{ width: 10, height: 10, borderRadius: 5, background: "#86efac" }} />
          <span style={{ marginLeft: 10, fontFamily: "JetBrains Mono, ui-monospace, monospace" }}>icon-close.svg</span>
          <span style={{ marginLeft: "auto", fontVariantNumeric: "tabular-nums", fontFamily: "JetBrains Mono, ui-monospace, monospace", color: frame > foldStart ? MINT : MUTED, fontWeight: 600 }}>{bytes} B</span>
        </div>
        <div style={{ position: "relative", padding: "18px 24px", fontFamily: "JetBrains Mono, ui-monospace, monospace", fontSize: 15.5, lineHeight: `${lineHeight}px` }}>
          {INPUT.map((l, i) => {
            const passed = sweep - i; // >1 fully processed, 0..1 in progress
            const p = Math.max(0, Math.min(1, passed));
            const isDrop = l.kind === "drop";
            const isEdit = l.kind === "edit";
            const y = interpolate(fold, [0, 1], [i * lineHeight, (isDrop ? i : targets[i]) * lineHeight]);
            const opacity = isDrop ? interpolate(p, [0, 1], [1, 0.18]) * (1 - fold) : 1;
            const strike = isDrop ? p : 0;
            const showTo = isEdit && p >= 0.5;
            const hl = passed > 0 && passed < 1.2 ? interpolate(passed, [0, 0.6, 1.2], [0, 1, 0]) : 0;
            return (
              <div key={i} style={{ position: "absolute", left: 24 + l.indent * 22, top: 18 + y, whiteSpace: "pre", opacity, color: isDrop ? MUTED : INK }}>
                <span style={{ position: "absolute", inset: -3, left: -8, right: -8, borderRadius: 6, background: `${VIOLET}14`, opacity: hl }} />
                <span style={{ position: "relative", textDecoration: strike > 0.5 ? "line-through" : "none", color: showTo ? VIOLET : undefined, transition: "none" }}>
                  {showTo ? l.to : l.text}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* plugin ticker */}
      <div style={{ position: "absolute", left: 936, top: 72, width: 272, opacity: appear }}>
        <div style={{ fontSize: 12, letterSpacing: "0.1em", textTransform: "uppercase", color: MUTED, fontWeight: 600 }}>pipeline</div>
        <div style={{ marginTop: 10, fontFamily: "JetBrains Mono, ui-monospace, monospace", fontSize: 14, minHeight: 60 }}>
          {PLUGINS.map((name, i) => {
            const done = i < pluginIndex || frame >= foldStart;
            const active = showPlugin && i === pluginIndex;
            return (
              <div key={name} style={{ display: "flex", alignItems: "center", gap: 8, height: 26, color: active ? INK : done ? MUTED : `${MUTED}66` }}>
                <span style={{ width: 8, height: 8, borderRadius: 4, background: done ? MINT : active ? VIOLET : LINE, transform: active ? "scale(1.4)" : "none" }} />
                <span style={{ fontWeight: active ? 600 : 400 }}>{name}</span>
              </div>
            );
          })}
        </div>

        {/* result */}
        <div style={{ marginTop: 26, padding: 18, borderRadius: 16, background: "#fff", border: `1px solid ${LINE}`, opacity: interpolate(frame, [foldStart, foldEnd], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }), transform: `translateY(${interpolate(fold, [0, 1], [12, 0])}px)` }}>
          <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
            <Icon size={56} color="#ef4444" />
            <div>
              <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: "-0.02em", color: INK }}>−{Math.round((1 - bytes / 836) * 100)}%</div>
              <div style={{ fontSize: 13, color: MUTED }}>836 B → {bytes} B · 0 px changed</div>
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
