import { Composition, Folder } from "remotion";
import { TwigIntro } from "./TwigIntro";
import { Opening } from "./scenes/Opening";
import { Keyboard } from "./scenes/Keyboard";
import { Organization } from "./scenes/Organization";
import { Tools } from "./scenes/Tools";
import { Repositories } from "./scenes/Repositories";
import { Welcome } from "./scenes/Welcome";
import { Closing } from "./scenes/Closing";

export const RemotionRoot = () => (
  <>
    <Composition
      id="TwigIntro"
      component={TwigIntro}
      durationInFrames={1050}
      fps={30}
      width={1920}
      height={1080}
    />
    <Folder name="Scenes">
      <Composition
        id="Opening"
        component={Opening}
        durationInFrames={135}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Keyboard"
        component={Keyboard}
        durationInFrames={180}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Organization"
        component={Organization}
        durationInFrames={165}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Tools"
        component={Tools}
        durationInFrames={180}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Repositories"
        component={Repositories}
        durationInFrames={165}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Welcome"
        component={Welcome}
        durationInFrames={180}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Closing"
        component={Closing}
        durationInFrames={135}
        fps={30}
        width={1920}
        height={1080}
      />
    </Folder>
  </>
);
