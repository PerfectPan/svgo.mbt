import { Config } from "@remotion/cli/config";
import { enableTailwind } from "@remotion/tailwind-v4";

Config.overrideBundlerConfig((current) => enableTailwind(current));
Config.setVideoImageFormat("jpeg");
