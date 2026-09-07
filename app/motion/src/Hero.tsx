// Hero animation: a verbose editor export is stripped line by line and folds
// into the one-line optimized document, while the byte counter drops.
// Styled with Tailwind v4 (see style.css); rendered to ../hero.mp4.
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

export const HERO_FPS = 30;
export const HERO_WIDTH = 1280;
export const HERO_HEIGHT = 720;
export const HERO_DURATION = HERO_FPS * 9;

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

const Icon = ({ size }: { size: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <g fill="#ef4444" transform="translate(2 2)">
      <path d="M0 0h20v20H0z" />
      <path d="M4 4l12 12M16 4 4 16" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
    </g>
  </svg>
);

const LINE_HEIGHT = 30;

export const Hero = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // timeline (seconds): 0-1 card appears, 1-4.5 plugins sweep, 4.8-6 fold, 6-9 hold
  const sweepStart = fps * 1.0;
  const sweepEnd = fps * 4.5;
  const foldStart = fps * 4.8;
  const foldEnd = fps * 6.0;

  const sweep = interpolate(frame, [sweepStart, sweepEnd], [0, INPUT.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const fold = interpolate(frame, [foldStart, foldEnd], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const appear = spring({ frame, fps, config: { damping: 200 } });
  const bytes = Math.round(interpolate(frame, [sweepStart, sweepEnd, foldEnd], [836, 330, 276], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.quad) }));
  const pluginIndex = Math.min(PLUGINS.length - 1, Math.floor(interpolate(frame, [sweepStart, sweepEnd], [0, PLUGINS.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })));
  const sweeping = frame >= sweepStart && frame < foldStart;
  const folded = frame >= foldStart;
  const resultIn = interpolate(frame, [foldStart, foldEnd], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // vertical slot of each surviving line after the fold (dropped lines collapse)
  let survivors = 0;
  const targets = INPUT.map((l) => (l.kind === "drop" ? -1 : survivors++));

  return (
    <AbsoluteFill className="bg-white font-sans text-ink">
      {/* soft colour wash, same as the page hero */}
      <div className="absolute inset-0 bg-[radial-gradient(600px_400px_at_15%_10%,rgb(5_150_105/0.14),transparent_60%),radial-gradient(500px_400px_at_90%_90%,rgb(20_184_166/0.16),transparent_60%)]" />

      {/* code card */}
      <div
        className="absolute left-[72px] top-[72px] h-[576px] w-[820px] overflow-hidden rounded-[20px] border border-line bg-white shadow-[0_30px_80px_-40px_rgb(15_40_60/0.30)]"
        style={{ opacity: appear, transform: `translateY(${(1 - appear) * 24}px)` }}
      >
        <div className="flex h-11 items-center gap-2 border-b border-line px-[18px] text-[13px] text-muted">
          <span className="size-2.5 rounded-full bg-red-300" />
          <span className="size-2.5 rounded-full bg-amber-300" />
          <span className="size-2.5 rounded-full bg-green-300" />
          <span className="ml-2.5 font-mono">icon-close.svg</span>
          <span className={`ml-auto font-mono font-semibold tabular-nums ${folded ? "text-mint" : "text-muted"}`}>{bytes} B</span>
        </div>
        <div className="relative px-6 py-[18px] font-mono text-[15.5px]" style={{ lineHeight: `${LINE_HEIGHT}px` }}>
          {INPUT.map((l, i) => {
            const passed = sweep - i; // >1 fully processed, 0..1 in progress
            const p = Math.max(0, Math.min(1, passed));
            const isDrop = l.kind === "drop";
            const isEdit = l.kind === "edit";
            const y = interpolate(fold, [0, 1], [i * LINE_HEIGHT, (isDrop ? i : targets[i]) * LINE_HEIGHT]);
            const opacity = isDrop ? interpolate(p, [0, 1], [1, 0.18]) * (1 - fold) : 1;
            const struck = isDrop && p > 0.5;
            const rewritten = isEdit && p >= 0.5;
            const hl = passed > 0 && passed < 1.2 ? interpolate(passed, [0, 0.6, 1.2], [0, 1, 0]) : 0;
            return (
              <div
                key={i}
                className={`absolute whitespace-pre ${isDrop ? "text-muted" : "text-ink"}`}
                style={{ left: 24 + l.indent * 22, top: 18 + y, opacity }}
              >
                <span className="absolute -inset-y-[3px] -inset-x-2 rounded-md bg-accent/10" style={{ opacity: hl }} />
                <span className={`relative ${struck ? "line-through" : ""} ${rewritten ? "text-accent" : ""}`}>{rewritten ? l.to : l.text}</span>
              </div>
            );
          })}
        </div>
      </div>

      {/* plugin ticker + result */}
      <div className="absolute left-[936px] top-[72px] w-[272px]" style={{ opacity: appear }}>
        <div className="text-xs font-semibold uppercase tracking-[0.1em] text-muted">pipeline</div>
        <div className="mt-2.5 font-mono text-sm">
          {PLUGINS.map((name, i) => {
            const done = i < pluginIndex || folded;
            const active = sweeping && i === pluginIndex;
            return (
              <div key={name} className={`flex h-[26px] items-center gap-2 ${active ? "font-semibold text-ink" : done ? "text-muted" : "text-muted/40"}`}>
                <span className={`size-2 rounded-full ${done ? "bg-mint" : active ? "scale-[1.4] bg-accent" : "bg-line"}`} />
                <span>{name}</span>
              </div>
            );
          })}
        </div>

        <div
          className="mt-[26px] rounded-2xl border border-line bg-white p-[18px]"
          style={{ opacity: resultIn, transform: `translateY(${interpolate(fold, [0, 1], [12, 0])}px)` }}
        >
          <div className="flex items-center gap-3.5">
            <Icon size={56} />
            <div>
              <div className="font-display text-[30px] font-bold tracking-tight text-ink">−{Math.round((1 - bytes / 836) * 100)}%</div>
              <div className="text-[13px] text-muted">836 B → {bytes} B · 0 px changed</div>
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
