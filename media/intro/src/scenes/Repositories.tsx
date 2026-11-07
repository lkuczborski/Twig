import {
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, Shot } from "../Design";

export const Repositories = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Scene dark chapter="04 / BRING YOUR REPOSITORIES">
      <Interactive.Div
        name="Repository headline"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          top: 210,
          fontSize: 122,
          lineHeight: 1.03,
          letterSpacing: -5.7,
          fontWeight: 600,
          opacity: interpolate(frame, [0, 24], [0, 1], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        More branches.
        <br />
        One place.
      </Interactive.Div>
      <Interactive.Div
        name="Repository scope"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 155,
          top: 530,
          width: 820,
          fontSize: 40,
          lineHeight: 1.45,
          color: "#D1E0BD",
          opacity: interpolate(frame, [20, 44], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Add any local Git repository.
        <br />
        All its worktrees, alongside Codex.
      </Interactive.Div>
      <Shot
        name="Real add repository control"
        src="screens/repository-settings.png"
        width={900}
        height={246.524}
        imageWidth={899.9992}
        imageTop={0.00248}
        imageLeft={0.0004}
        premountFor={fps}
        style={{
          left: 150,
          top: 705,
          borderRadius: 18,
          opacity: interpolate(frame, [45, 65], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: interpolate(frame, [45, 80], ["0px 40px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      />
      <Interactive.Svg
        name="Repository branch diagram"
        premountFor={fps}
        viewBox="0 0 650 650"
        style={{
          position: "absolute",
          left: 1120,
          top: 220,
          width: 650,
          height: 650,
        }}
      >
        <Interactive.Path
          name="Main checkout"
          d="M 325 560 L 325 110"
          stroke="#B9D29B"
          strokeWidth={6}
          fill="none"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={interpolate(frame, [16, 75], [1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
        <Interactive.Path
          name="First worktree"
          d="M 325 440 C 325 330 130 370 130 220"
          stroke="#B9D29B"
          strokeWidth={6}
          fill="none"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={interpolate(frame, [42, 95], [1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
        <Interactive.Path
          name="Second worktree"
          d="M 325 340 C 325 245 520 300 520 150"
          stroke="#B9D29B"
          strokeWidth={6}
          fill="none"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={interpolate(frame, [62, 115], [1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
        <circle cx="325" cy="560" r="25" fill="#E0E8CB" />
        <circle
          cx="325"
          cy="110"
          r="25"
          fill="#C1D8A3"
          opacity={interpolate(frame, [62, 78], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
        <circle
          cx="130"
          cy="220"
          r="25"
          fill="#C1D8A3"
          opacity={interpolate(frame, [80, 96], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
        <circle
          cx="520"
          cy="150"
          r="25"
          fill="#C1D8A3"
          opacity={interpolate(frame, [100, 116], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
      </Interactive.Svg>
      <Interactive.Div
        name="Repository diagram label"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 1235,
          top: 877,
          fontSize: 26,
          letterSpacing: 2.5,
          color: "#D1E0BD",
          opacity: interpolate(frame, [70, 95], [0, 0.85], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        YOUR LOCAL GIT WORKSPACE
      </Interactive.Div>
    </Scene>
  );
};
