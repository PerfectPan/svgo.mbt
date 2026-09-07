import { Composition } from "remotion";
import { Hero, HERO_DURATION, HERO_FPS, HERO_HEIGHT, HERO_WIDTH } from "./Hero";

export const Root = () => (
  <Composition
    id="Hero"
    component={Hero}
    durationInFrames={HERO_DURATION}
    fps={HERO_FPS}
    width={HERO_WIDTH}
    height={HERO_HEIGHT}
    defaultProps={{ theme: "light" as const }}
  />
);
