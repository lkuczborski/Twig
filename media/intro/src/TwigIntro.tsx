import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { useVideoConfig } from "remotion";
import { Opening } from "./scenes/Opening";
import { Keyboard } from "./scenes/Keyboard";
import { Organization } from "./scenes/Organization";
import { Tools } from "./scenes/Tools";
import { Repositories } from "./scenes/Repositories";
import { Welcome } from "./scenes/Welcome";
import { Closing } from "./scenes/Closing";

export const TwigIntro = () => {
  const { fps } = useVideoConfig();
  return (
    <TransitionSeries name="Twig intro film">
      <TransitionSeries.Sequence
        name="Meet Twig"
        durationInFrames={135}
        premountFor={fps}
      >
        <Opening />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="Keyboard and fuzzy search"
        durationInFrames={180}
        premountFor={fps}
      >
        <Keyboard />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="Pins groups and labels"
        durationInFrames={165}
        premountFor={fps}
      >
        <Organization />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="Your editor and terminal"
        durationInFrames={180}
        premountFor={fps}
      >
        <Tools />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="Any local Git repository"
        durationInFrames={165}
        premountFor={fps}
      >
        <Repositories />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="Welcome and launch at login"
        durationInFrames={180}
        premountFor={fps}
      >
        <Welcome />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: 15 })}
      />
      <TransitionSeries.Sequence
        name="One shortcut away"
        durationInFrames={135}
        premountFor={fps}
      >
        <Closing />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};
