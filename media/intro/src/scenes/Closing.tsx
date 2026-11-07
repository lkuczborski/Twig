import {
  CanvasImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene } from "../Design";

export const Closing = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene dark>
      <CanvasImage
        name="Closing Twig icon"
        src={staticFile("twig-icon.png")}
        premountFor={fps}
        style={{
          position: "absolute",
          left: 858,
          top: 145,
          width: 204,
          height: 204,
          opacity: interpolate(frame, [0, 24], [0, 1], {
            extrapolateRight: "clamp",
          }),
          scale: interpolate(frame, [0, 44], [0.85, 1], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
        }}
      />
      <Interactive.Div
        name="Closing headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 425,
          width: 1620,
          textAlign: "center",
          fontSize: 133,
          lineHeight: 1.05,
          letterSpacing: -6.5,
          fontWeight: 600,
          opacity: interpolate(frame, [10, 34], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [10, 40], ["0px 40px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Meet the next Twig.
      </Interactive.Div>
      <Interactive.Div
        name="Closing promise"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 630,
          width: 1620,
          textAlign: "center",
          fontSize: 48,
          lineHeight: 1.2,
          color: "#D3E3BD",
          opacity: interpolate(frame, [30, 54], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Your worktrees. One shortcut away.
      </Interactive.Div>
      <Interactive.Div
        name="Closing shortcut"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 800,
          top: 780,
          width: 320,
          textAlign: "center",
          fontSize: 52,
          letterSpacing: 18,
          color: "#D3E3BD",
          opacity: interpolate(frame, [50, 75], [0, 0.65], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        ⌃ ⇧ T
      </Interactive.Div>
    </Scene>
  );
};
