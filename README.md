<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Twig app icon">
</p>

<h1 align="center">Twig</h1>
<p align="center"><strong>Your worktrees. One shortcut away.</strong></p>
<p align="center">A small native macOS menu-bar app for getting back to the right project in the right editor.</p>
<p align="center">
  <a href="https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip">Download v0.2</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a> ·
  <a href="LICENSE">MIT License</a>
</p>

<p align="center">
  <img src="docs/assets/twig-menu.png" width="360" alt="Twig showing date-grouped Activity, project types, editor icons, and local Git change and conflict indicators">
  <br><sub>Actual native interface with demonstration repositories, captured with CleanShot X on macOS 27.2.</sub>
</p>

## Pick up where you left off

Press **Control–Shift–T**, type a few letters, and open the worktree you need. Twig finds your Codex worktrees automatically, lets you add other local Git repositories, and detects the right editor and project target for each checkout.

**Twig v0.2** makes that everyday workflow faster:

- **Stay on the keyboard.** Use a configurable global shortcut, fuzzy search, arrow-key selection, and Return to open. Jump back to your previous worktree with **Shift–Command–Return**.
- **Pick up recent work.** Activity groups worktrees into Today, weekdays from this week, Last week, and older dates. Switch to alphabetical Project groups in **Settings → Worktree list → Sort by**. Pins stay at the top, and your choice is saved.
- **Recognize your work.** See project types, destination-editor icons, and recorded last-opened times alongside branch names. Add searchable personal labels; long branches keep their distinctive endings visible.
- **See local Git status.** Spot changed files, unresolved conflicts, and commits ahead or behind the locally known upstream. Checks run in the background without fetching; unavailable status never implies a clean checkout.
- **Choose your tools.** Open once in another supported installed editor, save an editor for a whole repository, or open Apple's Terminal in the selected worktree. Individual worktree choices still take priority.
- **Bring your repositories.** Add a local checkout or bare Git repository to discover its existing worktrees alongside Codex. Unavailable sources stay visible in Settings; removing a source leaves its files on disk.
- **Get started quickly.** Welcome shows a scrollable list of discovered worktrees, explains the shortcut, and offers optional launch at login. Reopen it from Settings at any time.

Twig still opens the project itself—including Xcode workspaces and nested project targets—rather than making you find it inside a folder. Every automatic suggestion has an explanation and can be overridden.

## Install

1. [Download Twig v0.2](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip).
2. Unzip it and move **Twig.app** to **Applications**.
3. Open Twig. The welcome window introduces your worktrees; the branch symbol stays in your menu bar.

**macOS 14 or later · Apple Silicon and Intel · Developer ID signed and notarized**

Twig has no Dock icon. Liquid Glass is available on macOS 26 and later; earlier versions use native translucent material. Launch at login is optional and can be changed in Settings. [SHA-256 checksum](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip.sha256).

**Updated v0.2 (0.2.0, build 3):** this download includes the worktree details, Activity date sections, and menu-bar refinements. If you downloaded v0.2 earlier, download it again. Quit Twig before replacing the app in Applications. Saved discovery settings, editor choices, pins, labels, and open history are preserved; the former grouping preference migrates to Activity or Project. New preferences default to Activity. Automatic updates are not yet included.

Read the [v0.2 release notes](docs/RELEASE_NOTES_v0.2.md).

## Keyboard and actions

| Shortcut | Action |
| --- | --- |
| ⌃⇧T | Show or hide Twig from any app; configurable in Settings |
| ↑ / ↓ | Select the previous or next visible worktree |
| Return | Open the selected worktree |
| ⇧⌘Return | Reopen the previous successfully opened worktree |
| Option-click | Open the worktree folder in Finder |
| ⌘R | Refresh |
| ⌘, | Settings |
| Escape | Dismiss Twig |
| ⌘Q | Quit Twig |

Only the configurable global shortcut works from another app; the other keyboard shortcuts apply while Twig is focused. The gear menu contains the previous-worktree action, **Add Repository…**, Settings, and Quit. Each row's actions menu contains pins, labels, opening choices, Finder actions, path copying, and **Project & detection details**.

Fuzzy search covers project names, branches, personal labels, and editor names. Folder paths use literal matching to keep shared directory prefixes from producing unrelated matches.

## How it works

Twig reads local Git metadata and inspects project structure and small configuration snippets to suggest an installed editor. It opens project and directory URLs through macOS. Discovery never runs project scripts, build tools, or hooks.

| Project evidence | Examples of suggested editors |
| --- | --- |
| Xcode projects, workspaces, Swift packages | Xcode |
| VS Code workspaces and editor metadata | Visual Studio Code, Cursor, Windsurf, Zed |
| JetBrains metadata and language manifests | IntelliJ IDEA, PyCharm, WebStorm, GoLand, CLion, RustRover, PhpStorm, RubyMine |
| Android, Flutter, .NET, game projects | Android Studio, Rider |
| R projects and other source folders | RStudio or an installed general editor |

A saved worktree choice takes priority, followed by a repository editor choice, project detection, and your fallback editor. An installed general editor or Finder handles projects without another match. Repository choices resolve the project target inside each checkout. **Open once with…** leaves saved editor choices intact. Mixed repositories expose their detected targets in **Project & detection details**.

Codex discovery uses `~/.codex/worktrees`, or `$CODEX_HOME/worktrees` when supplied at launch. Choose another Codex home in Settings, or use **Add Repository…** for other local repositories. Only existing local checkouts appear; archived, deleted, and remote worktrees are not reconstructed. “Recent” means observed filesystem/Git activity or the last successful open through Twig, rather than chat activity.

Activity uses gray date headings and spacing to separate work without extra rules or a permanent keyboard-hint footer. The panel aligns to an edge of its menu-bar icon and stays within the screen. On macOS 27, clicking the icon keeps its native selection visible while the panel is open, including during search.

Filesystem events invalidate cached results. When Twig's views are hidden, changes wait without rescanning; unchanged openings reuse cached results. Manual refresh remains available.

**Local. Private. Yours.** No account, analytics, or cloud service. Twig does not read Codex conversations or credentials. Pins, labels, editor choices, and discovery sources are saved locally; labels do not rename Git branches or folders.

## Build from source

Develop with **Xcode 27.1 or 27.2**. CI checks Xcode 27.1; the v0.2 release workflow pins Xcode 27.2. The app runs on macOS 14 or later and has no third-party package dependencies.

```sh
git clone https://github.com/lkuczborski/Twig.git
cd Twig
./script/build_and_run.sh
./script/test.sh
```

The run script stages an ad-hoc signed development app in `dist/Twig.app` and opens it using your saved Twig preferences. Use `./script/build_and_run.sh --build` to build without launching. The separate [release workflow](docs/RELEASING.md) builds both architectures, signs, notarizes, staples, and checks the extracted archive before publication.

To explore the actual interface using invented repositories and separate demo preferences:

```sh
./script/build_and_run.sh --demo          # Menu with sample worktrees
./script/build_and_run.sh --demo-welcome  # Include the welcome window
./script/build_and_run.sh --demo-details  # Row details with real local Git states
./script/build_and_run.sh --demo-activity # Date-grouped Activity for screenshots
```

Each demo creates fresh Git fixtures under `dist/demos/`; it does not copy personal projects or conversations. Demo mode still uses real installed editors and real macOS login-item controls.

Read the [development guide](docs/DEVELOPMENT.md), [architecture](docs/ARCHITECTURE.md), [verification notes](docs/VERIFICATION.md), and [roadmap](docs/ROADMAP.md). Ideas and reproducible bug reports are welcome in [Issues](https://github.com/lkuczborski/Twig/issues).

## License

[MIT](LICENSE) · Copyright © 2026 Łukasz Kuczborski.
