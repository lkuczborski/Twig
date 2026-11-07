# Developing Twig

A native macOS menu bar app for opening Codex and other local Git worktrees in the right editor.

Twig discovers active local Codex worktrees, reads their current Git branches, and ranks launch targets from project files and editor configuration. Click a row to open its suggested project. The actions menu lets you remember an editor, choose a specific detected project, open the folder in Finder, reveal it in its enclosing folder, or copy its path.

## Run

Development supports Xcode 27.1 and 27.2. CI selects Xcode 27.1; the v0.2 release script requires Xcode 27.2. The deployment target remains macOS 14. No third-party dependencies.

```sh
./script/build_and_run.sh
```

The same command is wired to the Codex **Run** button. It builds and signs a local development bundle at `dist/Twig.app`, then launches it. Look for the **branch icon in the menu bar**; Twig deliberately has no Dock icon or main window. You can also open `Package.swift` in Xcode.

```sh
./script/build_and_run.sh --build    # Build a local app bundle without launching
./script/build_and_run.sh --verify   # Build, launch, check the process
./script/build_and_run.sh --preview  # Development window with the same menu UI
./script/build_and_run.sh --demo-details # Isolated fixtures for unreleased row details
./script/test.sh                     # Swift Testing fixture suite
```

Optional `--debug`, `--logs`, and `--telemetry` modes are supported by the run script. The toolchain helper honors `DEVELOPER_DIR` and `TWIG_SDK_PATH`; it can use separately installed Command Line Tools when Xcode is not configured. A CLT SDK compatibility fallback is documented in the helper. The development app bundle is ad-hoc signed. Distribution builds use the separate Developer ID signing and notarization workflow in [RELEASING.md](RELEASING.md).

`--demo-details` creates fresh repositories and separate Twig preferences under `dist/demos`, then opens the native preview. Its real Git fixtures include a clean Swift package, modified and untracked files, a local upstream with an ahead commit, and an unresolved merge conflict with ahead/behind counts. Saved successful-open ages range from recent to a day ago, and Website has no open history. No network or personal projects/preferences are used. The [feature notes](features/WORKTREE_DETAILS.md) describe the exact cases and completed checks. This implementation remains unreleased; the public v0.2 download is unchanged.

The generator stores Foundation-compatible canonical preference keys, including macOS temporary aliases such as `/private/tmp` → `/tmp`. This keeps pins, labels, and open history attached to their discovered checkout IDs even when the development worktree lives under a temporary directory.

## Use

- Press Control–Shift–T from another app, then fuzzy-search project names, branches, personal labels, or selected editors. Folder paths use literal matching. Arrow keys choose the result; Return opens it. Shift–Command–Return reopens the previous successful worktree.
- Click a worktree to launch the chosen IDE with the correct project, workspace, manifest, or folder URL.
- Option-click a worktree to open its folder in Finder.
- Use **Worktree editor** or **Repository editor** to save an installed editor for that scope. **Automatic** removes the override; **Open once with…** leaves saved choices intact. **Open in Terminal** opens the current worktree directory.
- Pin worktrees, add personal labels, and group by repository. Use **Add Repository…** to include local checkout or bare-repository roots alongside Codex. Welcome and optional launch at login are available in Settings.

In the development build, use the **Activity / Project** segmented control below search. Activity keeps recent worktrees together across projects; Project shows every project alphabetically and retains recent-first order inside it. Pins remain above both views. Search temporarily disables the switch and ranks results by relevance; clearing the query restores the saved view. The selected worktree remains selected and is scrolled into view when changing modes.
- Use **Project & detection details** to see the complete branch and path, the reason for each suggestion, and choose a particular nested project.
- Settings lets you change Codex home and choose a fallback editor. An explicit worktree override takes priority; unavailable overrides produce a helpful error.
- The compact menu keeps two lines per worktree and preserves branch identity. Development work adds project type, successful-open age, editor icons, and local Git status within that layout. Settings and Quit are in the gear menu.
- On macOS 26+, the panel uses native SwiftUI Liquid Glass directly over the content behind it. A small AppKit bridge presents a transparent window without an extra frosted backdrop. Search keeps the panel size stable, including when no results match.
- Filesystem notifications keep the list current. While all Twig views are hidden, Twig records pending changes without scanning; it refreshes when next shown. Unchanged openings reuse cached results. ⌘R forces a full refresh; Settings is ⌘, and Quit is ⌘Q while Twig is focused.

The default discovery root is `$CODEX_HOME/worktrees` when the launching process supplies `CODEX_HOME`, otherwise `~/.codex/worktrees`. Finder-launched apps do not inherit shell startup variables; use Settings for a custom root. Only existing local worktrees are shown, not deleted/archived folders or remote machines.

“Recent” means observed source/Git metadata activity or the last successful open from Twig. It does not mean Codex chat activity. Detached HEADs show a commit identifier instead of inventing a branch.

The development **Opened … ago** label uses only a recorded successful project open through Twig, including open-once editor actions. Filesystem activity still contributes to ordering but never manufactures an open-history label. No age appears for a worktree that Twig has not successfully opened. Local Git ahead/behind values compare locally known refs; status never fetches and does not imply up-to-date remote state.

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

- `Sources/TwigCore`: Foundation-only discovery, detection, resolution, app inventory, persistence, and development presentation/status helpers. `Git/` contains the bounded read-only Git status reader and parser.
- `Sources/TwigSync`: FSEvents subscriptions, change routing, and visibility-aware refresh state.
- `Sources/Twig`: SwiftUI views, observable app store, and a small AppKit boundary for menu-bar presentation, window visibility, and launching.
- `Sources/Twig/Services/WorktreeGitStatusStore.swift`: development status cache and scheduling, independent from discovery; at most four reads with a default two-second / 1 MiB budget per checkout, cancelled when all Twig views are hidden.
- `Sources/TwigInspect`: read-only JSON diagnostics using the same core logic.
- `Tests/TwigCoreTests`: temporary fixtures for discovery, inference, caching, launching policy, app inventory, and persistence.
- `Tests/TwigSyncTests`: event routing, hidden-state coalescing, and real FSEvents integration tests.

```sh
swift run TwigInspect                  # Inspect local metadata without opening projects
swift run TwigInspect --codex-home /path/to/codex
```

See [architecture](ARCHITECTURE.md), [roadmap](ROADMAP.md), and [verification](VERIFICATION.md) for design decisions, remaining work, and what has been validated.
