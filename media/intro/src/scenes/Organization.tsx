import {
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, Shot } from "../Design";

export const Organization = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene dark chapter="02 / MAKE IT YOURS">
      <Shot
        name="Pinned and grouped worktrees"
        src="screens/menu-panel.png"
        width={672}
        height={786}
        imageWidth={672}
        premountFor={fps}
        style={{
          left: 152,
          top: 166,
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [0, 35], ["0px 70px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      />
      <Interactive.Div
        name="Organization headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 990,
          top: 220,
          fontSize: 124,
          lineHeight: 1.03,
          letterSpacing: -5.5,
          fontWeight: 600,
          opacity: interpolate(frame, [5, 25], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Less hunting.
        <br />
        More doing.
      </Interactive.Div>
      <Interactive.Div
        name="Pin benefit"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1000,
          top: 555,
          fontSize: 42,
          color: "#D7E3C5",
          opacity: interpolate(frame, [28, 46], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [28, 52], ["35px 0px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        01 <span style={{ marginLeft: 28 }}>Pin active work.</span>
      </Interactive.Div>
      <Interactive.Div
        name="Group benefit"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1000,
          top: 650,
          fontSize: 42,
          color: "#D7E3C5",
          opacity: interpolate(frame, [52, 70], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [52, 76], ["35px 0px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        02 <span style={{ marginLeft: 28 }}>Group by repository.</span>
      </Interactive.Div>
      <Interactive.Div
        name="Label benefit"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1000,
          top: 745,
          fontSize: 42,
          color: "#D7E3C5",
          opacity: interpolate(frame, [76, 94], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [76, 100], ["35px 0px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        03 <span style={{ marginLeft: 28 }}>Give it a familiar name.</span>
      </Interactive.Div>
      <Interactive.Div
        name="Pinned row focus"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 161,
          top: 290,
          width: 653,
          height: 99,
          border: "3px solid #B8D596",
          borderRadius: 13,
          boxShadow: "0 0 0 8px #B8D59615",
          opacity: interpolate(frame, [28, 40, 70, 85], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
    </Scene>
  );
};
