import {
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, Shot } from "../Design";

export const Tools = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene chapter="03 / YOUR PROJECT. YOUR TOOLS.">
      <Interactive.Div
        name="Tools headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 222,
          fontSize: 124,
          lineHeight: 1.03,
          letterSpacing: -6,
          fontWeight: 600,
          opacity: interpolate(frame, [0, 22], [0, 1], {
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [0, 32], ["0px 45px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Open it
        <br />
        your way.
      </Interactive.Div>
      <Interactive.Div
        name="Open once explanation"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 554,
          width: 770,
          fontSize: 40,
          lineHeight: 1.4,
          color: "#5A705B",
          opacity: interpolate(frame, [22, 42], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Try another editor once.
        <br />
        Open Terminal in the worktree.
        <br />
        Save an editor for the repository.
      </Interactive.Div>
      <Interactive.Div
        name="Tools footer"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 813,
          fontSize: 27,
          fontWeight: 600,
          letterSpacing: 1.3,
          color: "#28543D",
          opacity: interpolate(frame, [90, 115], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        ONE WORKTREE. ALL YOUR OPTIONS.
      </Interactive.Div>
      <Shot
        name="Actual launch menu"
        src="screens/opening-actions.png"
        width={690}
        height={807}
        imageWidth={690.00281}
        premountFor={fps}
        style={{
          left: 1080,
          top: 140,
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [0, 45], ["90px 0px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      />
      <Interactive.Div
        name="Open once highlight"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1286,
          top: 395,
          width: 471,
          height: 47,
          border: "3px solid #B3D58F",
          borderRadius: 9,
          opacity: interpolate(frame, [30, 40, 63, 73], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <Interactive.Div
        name="Terminal highlight"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1286,
          top: 443,
          width: 471,
          height: 47,
          border: "3px solid #B3D58F",
          borderRadius: 9,
          opacity: interpolate(frame, [73, 83, 106, 116], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <Interactive.Div
        name="Repository editor highlight"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1286,
          top: 557,
          width: 471,
          height: 47,
          border: "3px solid #B3D58F",
          borderRadius: 9,
          opacity: interpolate(frame, [116, 126, 156, 169], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
    </Scene>
  );
};
