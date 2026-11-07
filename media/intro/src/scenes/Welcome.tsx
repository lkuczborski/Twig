import {
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, Shot } from "../Design";

export const Welcome = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene chapter="05 / READY WHEN YOU ARE">
      <Interactive.Div
        name="Welcome headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 224,
          fontSize: 121,
          lineHeight: 1.03,
          letterSpacing: -6,
          fontWeight: 600,
          opacity: interpolate(frame, [0, 22], [0, 1], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        A better
        <br />
        first hello.
      </Interactive.Div>
      <Interactive.Div
        name="Welcome explanation"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 550,
          width: 770,
          fontSize: 39,
          lineHeight: 1.5,
          color: "#5A705B",
          opacity: interpolate(frame, [20, 44], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        See what’s ready to open.
        <br />
        Learn the shortcut.
        <br />
        Choose to launch at login.
      </Interactive.Div>
      <Interactive.Div
        name="Local and private"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 819,
          fontSize: 29,
          fontWeight: 600,
          color: "#29563D",
          opacity: interpolate(frame, [80, 105], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Local. Private. Yours.
      </Interactive.Div>
      <Shot
        name="First launch experience"
        src="screens/welcome.png"
        width={680}
        height={768}
        imageWidth={680}
        premountFor={fps}
        style={{
          left: 1090,
          top: 154,
          opacity: interpolate(frame, [0, 24], [0, 1], {
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [0, 45], ["60px 40px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      />
      <Interactive.Div
        name="Welcome first run focus"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1127,
          top: 325,
          width: 602,
          height: 284,
          border: "3px solid #5B8150",
          borderRadius: 19,
          opacity: interpolate(frame, [30, 45, 78, 92], [0, 0.75, 0.75, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
    </Scene>
  );
};
