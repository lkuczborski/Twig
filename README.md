# Twig

A native macOS menu bar app for picking up a Codex worktree in the right editor.

Twig discovers active local Codex worktrees, reads their current Git branches, and ranks launch targets from project files and editor configuration. Click a row to open its suggested project. The actions menu lets you remember an editor, choose a specific detected project, open the folder in Finder, reveal it in its enclosing folder, or copy its path.

## Run

Requires macOS 14 or later and Swift 6 tools (Xcode or compatible Command Line Tools). No third-party dependencies.

```sh
./script/build_and_run.sh
```

The same command is wired to the Codex **Run** button. It builds and signs a local development bundle at `dist/Twig.app`, then launches it. Look for the **branch icon in the menu bar**; Twig deliberately has no Dock icon or main window. You can also open `Package.swift` in Xcode.

```sh
./script/build_and_run.sh --build    # Build a local app bundle without launching
./script/build_and_run.sh --verify   # Build, launch, check the process
./script/build_and_run.sh --preview  # Development window with the same menu UI
./script/test.sh                     # Swift Testing fixture suite
```

Optional `--debug`, `--logs`, and `--telemetry` modes are supported by the run script. The toolchain helper honors `DEVELOPER_DIR` and `TWIG_SDK_PATH`; it can use separately installed Command Line Tools when Xcode is not configured. A CLT SDK compatibility fallback is documented in the helper. The app bundle is ad-hoc signed for local development, not notarized for distribution.

## Use

- Search by project, branch, folder path, or selected editor. Return opens the first match.
- Click a worktree to launch the chosen IDE with the correct project, workspace, manifest, or folder URL.
- Option-click a worktree to open its folder in Finder.
- Use **Always open with** to save an installed editor for this worktree. **Automatic** removes the override.
- Use **Project & detection details** to see the complete branch and path, the reason for each suggestion, and choose a particular nested project.
- Settings lets you change Codex home and choose a fallback editor. An explicit worktree override takes priority; unavailable overrides produce a helpful error.
- The compact menu shows only search, repository names, branch names, and action menus. Settings and Quit are in the gear menu.
- On macOS 26+, the panel uses native SwiftUI Liquid Glass directly over the content behind it. A small AppKit bridge presents a transparent window without an extra frosted backdrop. Search keeps the panel size stable, including when no results match.
- Filesystem notifications keep the list current. While the menu is closed, Twig records pending changes without scanning; it refreshes when next shown. Unchanged openings reuse cached results. ⌘R forces a full refresh; Settings is ⌘, and Quit is ⌘Q while Twig is focused.

The default discovery root is `$CODEX_HOME/worktrees` when the launching process supplies `CODEX_HOME`, otherwise `~/.codex/worktrees`. Finder-launched apps do not inherit shell startup variables; use Settings for a custom root. Only existing local worktrees are shown, not deleted/archived folders or remote machines.

“Recent” means observed source/Git metadata activity or the last successful open from Twig. It does not mean Codex chat activity. Detached HEADs show a commit identifier instead of inventing a branch.

## Project detection

Detection is a suggestion, not proof of your preferred editor. Explicit editor configuration generally outranks language heuristics. Only installed applications are considered, except that an unavailable saved override is preserved and reported.

| Evidence | Suggested editor |
| --- | --- |
| `.xcworkspace`, `.xcodeproj`, `Package.swift`, playgrounds, Apple source | Xcode |
| `.code-workspace`, `.vscode` | Visual Studio Code |
| `.idea` plus module SDK, manifest, or product metadata | Corresponding JetBrains IDE |
| Gradle Android plugin, Android manifest, Flutter/Dart | Android Studio |
| Maven, Gradle, SBT, Java/Kotlin/Scala, Clojure | IntelliJ IDEA |
| Python, JavaScript/TypeScript, PHP, Ruby, Go, C/C++, Rust | PyCharm, WebStorm, PhpStorm, RubyMine, GoLand, CLion, RustRover |
| .NET solutions/projects, Unity, Unreal project | Rider |
| R projects/packages | RStudio |
| Cursor, Windsurf, Zed, Sublime, Nova, legacy Fleet configuration | Corresponding editor |
| Elixir, Haskell, Julia, Terraform, Lua, shell, Zig, SQL, LaTeX, other source | General editor fallback |

Multiple candidates remain visible so mixed repositories and monorepos can be overridden. Specialized IDE integration is URL-based; it does not require command-line launchers. Detection reads up to four directory levels with entry/content budgets and skips Git internals, dependencies, build outputs, bundles, and symlinks. No project commands, hooks, or scripts run. Twig never reads Codex conversations or credentials and has no network client.

Preferences live in `~/Library/Application Support/Twig/preferences.json`. They are versioned and written atomically. Unreadable preferences are preserved; Settings offers an explicit recovery action that saves a backup before resetting.

## Development

- `Sources/TwigCore`: Foundation-only discovery, detection, resolution, app inventory, persistence.
- `Sources/TwigSync`: FSEvents subscriptions, change routing, and visibility-aware refresh state.
- `Sources/Twig`: SwiftUI views, observable app store, and a small AppKit boundary for menu-bar presentation, window visibility, and launching.
- `Sources/TwigInspect`: read-only JSON diagnostics using the same core logic.
- `Tests/TwigCoreTests`: temporary fixtures for discovery, inference, caching, launching policy, app inventory, and persistence.
- `Tests/TwigSyncTests`: event routing, hidden-state coalescing, and real FSEvents integration tests.

```sh
swift run TwigInspect                  # Inspect local metadata without opening projects
swift run TwigInspect --codex-home /path/to/codex
```

See [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), and [verification](docs/VERIFICATION.md) for design decisions, remaining work, and what has been validated.
