import React from "react";
import {
  AbsoluteFill,
  CanvasImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  type InteractivitySchema,
} from "remotion";

export const Scene: React.FC<{
  children: React.ReactNode;
  dark?: boolean;
  chapter?: string;
}> = ({ children, dark = false, chapter }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill
      style={{
        backgroundColor: dark ? "#102D25" : "#F1F1E8",
        color: dark ? "#F3F3E8" : "#163B2E",
        fontFamily: "Helvetica Neue, Arial, sans-serif",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: dark
            ? "radial-gradient(ellipse at 82% 24%, #244E3B 0%, transparent 62%)"
            : "radial-gradient(ellipse at 88% 20%, #DEE6D8 0%, transparent 65%)",
        }}
      />
      <svg
        viewBox="0 0 1920 1080"
        style={{
          position: "absolute",
          inset: 0,
          width: 1920,
          height: 1080,
          opacity: dark ? 0.12 : 0.1,
        }}
      >
        <path
          d="M 1310 1230 C 1310 950 1390 680 1550 430 C 1640 290 1720 140 1720 -120 M 1460 580 C 1300 430 1250 200 1280 -70 M 1390 740 C 1610 730 1770 600 1950 390"
          fill="none"
          stroke={dark ? "#C9DDAC" : "#527C51"}
          strokeWidth="3"
          pathLength="1"
          strokeDasharray="1"
          strokeDashoffset={interpolate(frame, [0, 2 * fps], [0.65, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}
        />
      </svg>
      {chapter ? (
        <Interactive.Div
          name="Chapter label"
          premountFor={fps}
          style={{
            position: "absolute",
            left: 150,
            top: 90,
            fontSize: 24,
            fontWeight: 600,
            letterSpacing: 3.6,
            opacity: interpolate(frame, [0, 18], [0, 0.7], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          {chapter}
        </Interactive.Div>
      ) : null}
      {children}
      <Interactive.Div
        name="Brand signature"
        premountFor={fps}
        style={{
          position: "absolute",
          left: 150,
          bottom: 62,
          fontSize: 22,
          fontWeight: 500,
          letterSpacing: 3,
          opacity: 0.5,
        }}
      >
        TWIG · NATIVE MACOS
      </Interactive.Div>
    </AbsoluteFill>
  );
};

type ShotProps = {
  src: string;
  width: number;
  height: number;
  imageWidth: number;
  imageTop?: number;
  imageLeft?: number;
  style?: React.CSSProperties;
};
const ShotInner: React.FC<ShotProps> = ({
  src,
  width,
  height,
  imageWidth,
  imageTop = 0,
  imageLeft = 0,
  style,
}) => {
  const { fps } = useVideoConfig();
  return (
    <Interactive.Div
      name="App capture"
      premountFor={fps}
      style={{
        position: "absolute",
        width,
        height,
        overflow: "hidden",
        borderRadius: 26,
        backgroundColor: "#222222",
        boxShadow: "0 46px 100px #001B2438, 0 7px 18px #001B2414",
        border: "1px solid #FFFFFF55",
        ...style,
      }}
    >
      <CanvasImage
        name="Actual Twig screenshot"
        src={staticFile(src)}
        premountFor={fps}
        style={{
          display: "block",
          width: imageWidth,
          position: "absolute",
          top: imageTop,
          left: imageLeft,
        }}
      />
    </Interactive.Div>
  );
};
const shotSchema = {
  imageLeft: {
    type: "number",
    hiddenFromList: false,
    default: 0,
    description: "Crop left",
  },
  src: {
    type: "asset",
    assetType: "image",
    default: "screens/menu-panel.png",
    description: "App screenshot",
  },
  width: {
    type: "number",
    hiddenFromList: false,
    default: 720,
    description: "Frame width",
  },
  height: {
    type: "number",
    hiddenFromList: false,
    default: 842,
    description: "Frame height",
  },
  imageWidth: {
    type: "number",
    hiddenFromList: false,
    default: 720,
    description: "Image width",
  },
  imageTop: {
    type: "number",
    hiddenFromList: false,
    default: 0,
    description: "Crop offset",
  },
} as const satisfies InteractivitySchema;
export const Shot = Interactive.withSchema({
  Component: ShotInner,
  componentName: "<Shot>",
  schema: shotSchema,
  wrapInSequence: true,
});

type KeyProps = {
  children: string;
  width?: number;
  delay?: number;
  style?: React.CSSProperties;
};
const KeyInner: React.FC<KeyProps> = ({
  children,
  width = 122,
  delay = 0,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <Interactive.Div
      name="Shortcut key"
      premountFor={fps}
      style={{
        width,
        height: 118,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        borderRadius: 22,
        fontSize: 62,
        fontWeight: 500,
        backgroundColor: "#FEFEF9",
        color: "#173E2D",
        border: "1px solid #CBD3C3",
        boxShadow: "0 9px 0 #C4CDBD, 0 17px 24px #183C2014",
        opacity: interpolate(frame, [delay, delay + 12], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
        translate: interpolate(
          frame,
          [delay, delay + 22],
          ["0px 35px", "0px 0px"],
          {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          },
        ),
        ...style,
      }}
    >
      {children}
    </Interactive.Div>
  );
};
export const Key = Interactive.withSchema({
  Component: KeyInner,
  componentName: "<Key>",
  schema: {
    children: { type: "text-content", default: "⌘", description: "Key" },
    width: {
      type: "number",
      hiddenFromList: false,
      default: 122,
      description: "Width",
    },
    delay: {
      type: "number",
      hiddenFromList: false,
      default: 0,
      description: "Entrance frame",
    },
  } satisfies InteractivitySchema,
  wrapInSequence: true,
});
