<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Twig app icon">
</p>

<h1 align="center">Twig</h1>
<p align="center"><strong>Your worktrees. The right editor. One click.</strong></p>
<p align="center">A small native macOS menu-bar app for getting back to your projects.</p>
<p align="center">
  <a href="https://github.com/lkuczborski/Twig/releases/latest">Download</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a> ·
  <a href="LICENSE">MIT License</a>
</p>

<p align="center">
  <img src="docs/assets/twig-menu.png" width="360" alt="Twig's menu showing example worktrees and their Git branches">
  <br><sub>Native SwiftUI, with Liquid Glass on macOS 26. Demonstration repositories shown.</sub>
</p>

## Pick up where you left off

Codex worktrees are useful until you have to hunt through folders to find the right checkout. The stable **v0.1** release puts your recent worktrees and their current Git branches in the menu bar, figures out which editor fits each project, and opens the right target when you click.

- **Open the project, not just its folder.** Xcode workspaces, IDE project files, and nested project targets are detected automatically.
- **Keep the choice yours.** Override an editor or project target for any individual worktree. Every suggestion has an explanation.
- **Find it quickly.** Search project names, branches, paths, or editors. Press Return to open the first match.
- **Get to Finder.** Option-click a row to open its folder. More actions let you reveal its enclosing folder or copy its path.
- **Stay current without polling.** Filesystem events invalidate cached results. Closed menus collect pending changes without rescanning.
- **Keep it local.** No account, analytics, cloud service, or project-code execution. Twig does not read Codex conversations or credentials.

## Install the stable release

1. [Download Twig v0.1](https://github.com/lkuczborski/Twig/releases/download/v0.1/Twig-v0.1-macos-universal.zip).
2. Unzip it and move **Twig.app** to **Applications**.
3. Open Twig and look for the branch symbol in your menu bar.

**macOS 14 or later · Apple Silicon and Intel · Developer ID signed and notarized**

Twig lives in the menu bar and has no Dock icon. Liquid Glass is available on macOS 26; earlier versions use a native translucent material. [SHA-256 checksum](https://github.com/lkuczborski/Twig/releases/download/v0.1/Twig-v0.1-macos-universal.zip.sha256).

## Next-version preview

The local **`codex/next-preview`** branch combines five feature worktrees. These features are implemented in the development preview; **v0.1 remains the published download**. No next-version release has been published.

- **Move through work by keyboard.** Configurable **Control–Shift–T** opens Twig. Fuzzy search, arrow-key selection, Return, and a previous-worktree action complete the keyboard workflow. Paths use literal matching so unrelated directory prefixes do not crowd the results.
- **Recognize the right checkout.** Pin active worktrees, group siblings by repository, and add personal labels. Long branch names keep their distinctive endings through middle truncation.
- **Get started quickly.** Welcome shows discovered worktrees, explains the shortcut, and offers a native launch-at-login setting. Welcome can be reopened from Settings.
- **Choose how to open.** Try an installed editor once, save an editor for the whole repository, or open Apple's Terminal. Worktree choices take priority over repository defaults; each checkout resolves its own project target.
- **Bring other Git repositories.** Add a checkout or bare repository to discover its existing linked worktrees alongside Codex. Saved unavailable roots remain visible in Settings. Removing a discovery source leaves its files on disk.

| Preview shortcut | Action |
| --- | --- |
| ⌃⇧T | Show or hide Twig from another app; configurable in Settings |
| ↑ / ↓ | Select the previous or next visible worktree |
| Return | Open the selected result |
| ⇧⌘Return | Reopen the previous successfully opened worktree |
| Escape | Dismiss Twig |

From the combined preview checkout, run the native app with invented repositories and separate demo preferences:

```sh
./script/build_and_run.sh --demo          # Menu preview with sample worktrees
./script/build_and_run.sh --demo-welcome  # Include the first-run welcome window
```

Each command creates fresh Git fixtures under `dist/demos/`; the sample content contains no personal projects or conversations. The demo uses real installed editors and real macOS login-item controls. Normal `./script/build_and_run.sh` uses your saved Twig preferences. Preview builds are locally ad-hoc signed.

See the [preview manifest and validation limits](docs/features/NEXT_VERSION.md) for feature branches, observed UI checks, and the remaining Terminal-directory, login-item, and release checks. The user has confirmed that Control–Shift–T opens the preview from another application.

## How it works

The published v0.1 discovers existing local checkouts under your Codex home, reads Git metadata for their branch names, and inspects project structure and small configuration snippets to suggest an installed editor. It opens URLs through macOS rather than running project scripts or shell launch commands. The preview also combines explicitly added Git repositories with this discovery source.

| Project evidence | Examples of suggested editors |
| --- | --- |
| Xcode projects, workspaces, Swift packages | Xcode |
| VS Code workspaces and editor metadata | Visual Studio Code, Cursor, Windsurf, Zed |
| JetBrains metadata and language manifests | IntelliJ IDEA, PyCharm, WebStorm, GoLand, CLion, RustRover, PhpStorm, RubyMine |
| Android, Flutter, .NET, game projects | Android Studio, Rider |
| R projects and other source folders | RStudio or an installed general editor |

A saved worktree choice takes priority over detection. In the preview, a repository editor default sits between the worktree choice and detection. If no suitable installed editor is found, Twig falls back to your chosen editor or Finder. Mixed repositories expose their detected targets in **Project & detection details**.

The default location is `~/.codex/worktrees`, or `$CODEX_HOME/worktrees` when supplied at launch. Choose another Codex home in Settings. Only existing local worktrees appear; archived, deleted, and remote worktrees are not reconstructed. “Recent” means observed filesystem/Git activity or the last successful open through Twig, rather than chat activity.

| Stable v0.1 shortcut | Action |
| --- | --- |
| Return | Open the first search result |
| Option-click | Open the worktree folder in Finder |
| ⌘R | Refresh |
| ⌘, | Settings |
| Escape | Dismiss Twig |
| ⌘Q | Quit Twig |

Keyboard shortcuts apply while Twig is focused. Settings and Quit are also in the gear menu.

## Build from source

Build and release with **Xcode 27.1**. CI selects this version explicitly. The app still runs on macOS 14 or later, and has no third-party package dependencies.

```sh
git clone https://github.com/lkuczborski/Twig.git
cd Twig
./script/build_and_run.sh
./script/test.sh
```

The build script stages a local development app in `dist/Twig.app`. A separate [release workflow](docs/RELEASING.md) builds both architectures, signs, notarizes, staples, and checks the extracted archive before publication.

Read the [development guide](docs/DEVELOPMENT.md), [architecture](docs/ARCHITECTURE.md), and [verification notes](docs/VERIFICATION.md) for the released foundation. The [preview manifest](docs/features/NEXT_VERSION.md) records the new features and their validation status; the [roadmap](docs/ROADMAP.md) separates those from future work. Ideas and reproducible bug reports are welcome in [Issues](https://github.com/lkuczborski/Twig/issues).

## License

[MIT](LICENSE) · Copyright © 2026 Łukasz Kuczborski.
