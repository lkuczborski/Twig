# Twig intro video

Editable source for Twig's 35-second introduction: 1920 × 1080 pixels, 30 fps, with seven scenes and no audio. The main composition is **TwigIntro**. Each scene also has its own composition in the **Scenes** folder for editing and reuse.

## Requirements

Use Node.js 20.19+, 22.13+, or a supported newer release, and npm. Exact dependency versions are recorded in `package-lock.json`. Install from this directory:

```sh
npm ci
```

## Preview and edit

```sh
npm run dev
```

Open the local URL printed by Remotion Studio and select **TwigIntro**. The scene components live in `src/scenes`; the timeline is in `src/TwigIntro.tsx`. Text, screenshot placement, motion, and scene durations can be edited in Studio or in the source files.

The artwork uses Helvetica Neue when available, followed by Arial and the system sans-serif font. Rendering on macOS matches the original typography most closely. Other systems may use the fallback font and have slightly different text spacing.

## Render

```sh
npm run lint
npm run render
```

The render command writes an H.264 MP4 to `out/Twig-intro-v0.2.mp4`. Remotion may download its rendering browser on the first run. To export a still from an individual scene:

```sh
npx remotion still Repositories out/repositories.png --frame=100
```

`npm run build` creates a Remotion bundle in `build/`. Dependencies, rendered files, bundles, and caches are intentionally excluded from the source archive.

## Scenes

| Time | Scene | Features |
| --- | --- | --- |
| 0–4.5s | Your work. Within reach. | Twig identity and native menu |
| 4–10s | A shortcut. A few letters. | Global shortcut, fuzzy search, list navigation, Return, previous worktree |
| 9.5–15s | Less hunting. More doing. | Pins, repository groups, personal labels |
| 14.5–20.5s | Open it your way. | Open once with, Terminal, repository editor choices |
| 20–25.5s | More branches. One place. | Local Git repositories and their linked worktrees |
| 25–31s | A better first hello. | Welcome screen, shortcut guidance, optional launch at login |
| 30.5–35s | Meet the next Twig. | Your worktrees. One shortcut away. |

Transitions overlap adjacent scenes by half a second. `tweet-draft.txt` contains an editable, unposted announcement draft.

## Asset provenance

`public/twig-icon.png` is Twig's existing app icon. The files in `public/screens` are native captures of the running Twig app using demonstration projects named Atlas, Grove, and Website. They are source pixels from the app, with no generated UI, reconstructed controls, or painted cursor removal.

The source assets are already cropped to contain the app content used by the film:

- `repository-settings.png`: a 920 × 252 native-pixel crop of the repository section. Window chrome, screen-sharing indicators, and local filesystem paths were excluded before packaging.
- `opening-actions.png`: the 720 × 842 app panel and its menu, with unused exterior padding removed.
- `welcome.png`: a 1040 × 1175 CleanShot-framed welcome view.
- The menu and keyboard screenshots are 720 × 842 captures of the app panel.

The scene layout compensates for the source crops to preserve the original framing and motion. The two source crops were checked against the corresponding native screenshot regions with zero differing decoded pixel channels. EXIF and text metadata were removed without changing image pixels. The archive contains no full desktop screenshots or local user paths.

## License

Twig's video source and supplied assets are distributed under the included MIT license. Remotion and the other npm dependencies retain their own licenses; check their terms for your intended use.
