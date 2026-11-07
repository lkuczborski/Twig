import {
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Key, Scene, Shot } from "../Design";

export const Keyboard = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene chapter="01 / FIND YOUR FLOW">
      <Interactive.Div
        name="Keyboard headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 220,
          fontSize: 124,
          lineHeight: 1.03,
          letterSpacing: -6,
          fontWeight: 600,
          translate: interpolate(frame, [0, 30], ["0px 45px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        A shortcut.
        <br />A few letters.
      </Interactive.Div>
      <Interactive.Div
        name="Shortcut keys"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 154,
          top: 558,
          display: "flex",
          gap: 18,
        }}
      >
        <Key name="Control" delay={12} premountFor={fps}>
          ⌃
        </Key>
        <Key name="Shift" delay={19} premountFor={fps}>
          ⇧
        </Key>
        <Key name="T" delay={26} premountFor={fps}>
          T
        </Key>
      </Interactive.Div>
      <Interactive.Div
        name="Shortcut hint"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 725,
          fontSize: 36,
          lineHeight: 1.45,
          color: "#5A705B",
          opacity: interpolate(frame, [35, 55], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Open from anywhere.
        <br />
        Fuzzy search finds your worktree.
      </Interactive.Div>
      <Shot
        name="Find by a few letters"
        durationInFrames={90}
        src="screens/keyboard-search.png"
        width={690}
        height={807}
        imageWidth={690}
        premountFor={fps}
        style={{
          left: 1080,
          top: 140,
          opacity: interpolate(frame, [0, 18], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [0, 40], ["100px 0px", "0px 0px"], {
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      />
      <Shot
        name="Choose using arrow keys"
        from={90}
        src="screens/keyboard-selection.png"
        width={690}
        height={807}
        imageWidth={690}
        premountFor={fps}
        style={{
          left: 1080,
          top: 140,
        }}
      />
      <Interactive.Div
        name="Keyboard navigation cue"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 156,
          top: 850,
          width: 770,
          textAlign: "left",
          color: "#54704F",
          fontSize: 30,
          lineHeight: 1.5,
          opacity: interpolate(frame, [100, 120], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [100, 125], ["0px 20px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        ↑ ↓ choose · <span style={{ fontWeight: 600 }}>↵ open</span>
        <br />
        ⇧⌘↵ back to your previous worktree
      </Interactive.Div>
    </Scene>
  );
};
