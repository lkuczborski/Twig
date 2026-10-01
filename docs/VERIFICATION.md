# Twig verification

Validated locally on Apple Silicon macOS 27, Swift 6.4 / Xcode. MVP checks were performed on 29 September 2026; the minimal UI and event-driven syncing iteration was checked on 1 October 2026.

## Automated checks

`./script/test.sh` passes **75 tests in eight suites**:

- 22 project-detection fixtures: project/workspace precedence, editor configuration, JetBrains product inference, Android Gradle content, nested projects, language families, source-only Xcode documents, path aliases/spaces, symlinks, ignored dependencies, deterministic ranking, and scan/read budgets.
- 14 discovery fixtures: current/detached/unborn HEAD, branch changes, loose/packed refs, relative git pointers, stale worktrees, missing/oversized metadata, symlink boundaries, reference cycles, SHA-256 revisions, and activity ordering.
- 12 launch-policy fixtures: installed-app filtering, saved overrides, unavailable apps, correct targets, containment, configured fallback priority, generic fallback, and Finder.
- 7 persistence fixtures: round trips, canonical keys, removing overrides, optional fields, version handling, atomic saves, and preserving corrupted data until explicit recovery.
- 3 installed-app fixtures: supported bundle IDs, vendor subfolders, preview aliases, root precedence, malformed metadata, depth limits, symlinks, and embedded helper exclusion.
- 3 scanner-cache fixtures: branch updates without repeated inference, targeted invalidation, new/removed/recreated worktrees, Codex home changes, and manual full refresh.
- 11 sync-state/routing fixtures: hidden changes remain pending, unchanged openings do no work, changes during a scan remain queued, ignored build/dependency/Git-object paths, linked metadata outside a checkout, topology changes, app inventory, dropped events, and deduplicated roots.
- 3 real FSEvents fixtures: changing linked Git HEAD emits a correctly routed event, creation of a missing watched root is observed through its parent, and subscriptions can stop and move to another root. These run outside the tool sandbox because it blocks the FSEvents daemon.

Shell scripts pass `bash -n`. Bundle metadata passes `plutil -lint`; the locally ad-hoc-signed bundle passes `codesign --verify --deep --strict`. Development launch is checked with the script’s `--verify` mode.

## Real local data

The latest read-only diagnostic found 15 extant Codex worktrees with no discovery warnings and identified installed Xcode. Branch labels for all 15 were cross-checked against `git symbolic-ref --short -q HEAD`, including detached HEAD results. Every resolved target existed. The count is a point-in-time snapshot; it changes when Codex creates or removes worktrees.

Diagnostic JSON was kept in a temporary local file because it contains personal paths/branch names. Reproduce with `swift run TwigInspect`.

## Native UI smoke checks

The UI automation tool could not bind directly to the accessory app's menu-only surface. `./script/build_and_run.sh --preview` builds a development window containing the **same WorktreeMenuView, store, services, settings, and actions** to make those interactions inspectable. Normal builds omit that preview scene.

Verified through native UI automation:

- The real list rendered, including branch names and detached commit labels; layout visually inspected.
- Searching for a repository reduced the list to the expected single worktree.
- Selecting “Always open with → Xcode” saved the override and changed the row's explanation.
- Clicking that row opened Xcode at the exact selected worktree folder; the Xcode project navigator and branch control confirmed it.
- Restoring “Automatic” removed the test override and restored the detected `Package.swift` explanation.
- Settings opened with the active Codex home and the correct fallback value.
- “Open enclosing folder” opened Finder at the parent directory and selected the exact worktree folder.

For the 1 October iteration, native preview checks confirmed that the initial visibility notification populated the real list, repository/branch rows rendered without app logos or extra labels, search narrowed the list, and the gear and per-worktree menus retained their actions. Cache and hidden-refresh behavior were checked through the scanner and refresh-state tests; menu-only dismissal remains a release smoke check because the automation surface requires the preview window.

The final app was rebuilt in normal menu bar mode after these checks.

## Practical limits

Xcode is the only supported IDE installed on this test machine. Other editors' detection, bundle matching, and launch decisions have fixture coverage; their actual installed applications were not launched. Menu-bar popover placement/dismissal, VoiceOver, older macOS versions, and Intel hardware still need release testing. Project-target detail actions and preference recovery have code/core coverage but were not exhaustively exercised through every UI path.

This is a local development MVP, not a notarized distribution release. Heuristics cannot prove a user's preferred editor; use the per-worktree override for ambiguous repositories. Recency is filesystem/Git activity plus successful opens, not Codex chat recency.
