import {
  CanvasImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, Shot } from "../Design";

export const Opening = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene dark>
      <CanvasImage
        name="Twig icon"
        src={staticFile("twig-icon.png")}
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 130,
          width: 132,
          height: 132,
          opacity: interpolate(frame, [0, 18], [0, 1], {
            extrapolateRight: "clamp",
          }),
          scale: interpolate(frame, [0, 30], [0.78, 1], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            output: "perceptual-scale",
          }),
        }}
      />
      <Interactive.Div
        name="Opening title"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 326,
          width: 930,
          fontSize: 142,
          lineHeight: 1.02,
          fontWeight: 600,
          letterSpacing: -7,
          opacity: interpolate(frame, [8, 32], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [8, 38], ["0px 44px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Your work.
        <br />
        Within reach.
      </Interactive.Div>
      <Interactive.Div
        name="Introducing Twig"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 674,
          fontSize: 43,
          fontWeight: 400,
          color: "#CDDEB5",
          opacity: interpolate(frame, [30, 52], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Meet the next Twig.
      </Interactive.Div>
      <Shot
        name="Twig hero"
        src="screens/menu-panel.png"
        width={630}
        height={737}
        imageWidth={630}
        premountFor={fps}
        style={{
          left: 1140,
          top: 162,
          opacity: interpolate(frame, [18, 42], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [18, 75], ["0px 120px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [18, 135], [0.93, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            output: "perceptual-scale",
          }),
        }}
      />
    </Scene>
  );
};
