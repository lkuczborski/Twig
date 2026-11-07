# Twig verification

## Unreleased worktree details — 7 November 2026

The development implementation adds project type, successful-open age, destination-editor icons, and local Git change/conflict/ahead/behind indicators to the existing two-line rows. It remains **unreleased**; the public v0.2 app and its download are unchanged. See the [feature record](features/WORKTREE_DETAILS.md) for behavior and limits.

The combined development build passed. An initial complete run passed **152 tests: 130 core, including 16 Git tests, and 22 sync**. A transport-denial test and an `info/exclude` routing test were then added; focused reruns passed **17 Git tests, 20 routing tests, and 3 real FSEvents tests**. Together, those runs cover the final **154-test inventory: 131 core and 23 sync**. This records a complete baseline plus targeted followups, not a single final 154-test run.

Native preview checks used disposable repositories with real Git state and separate preferences. Verified:

- Two changed files, one commit ahead, and one conflicted file with one commit ahead/one behind, matching Git's results for the corresponding fixtures.
- Swift and JS / TS project types, Xcode and Finder destination icons, saved successful-open ages, pins and labels, and preserved branch identity.
- Search and Down-arrow selection, plus exact open dates and all Git counts in the details view.
- Adding an untracked `LiveRefresh.md` file updated the visible changed-file count from **2 to 3** through the filesystem watcher. Adding that file to the common `.git/info/exclude` changed the count from **3 to 2** automatically, without manual refresh.

Independent review identified and corrected invalidation for `info/exclude` and attributes, the scope of known linked-worktree index events, and conservative status refresh for `MustScanSubDirs` and ancestor events. Automated routing coverage passed; the native file-addition and `info/exclude` checks also confirmed automatic status updates.

The demo generator now matches Foundation's canonical spelling of macOS temporary aliases such as `/private/tmp` → `/tmp`, so saved pin, label, and last-opened keys match discovered checkout IDs. The corrected keys were checked directly with Foundation; ordinary `/Users` paths remain unchanged.

The default reader budget is two seconds and 1 MiB across a checkout's commands, with at most four checkout reads running concurrently. Positive finite timeout overrides are bounded at 60 seconds. Core tests cover the status reader's local-only process boundaries; a filtered-repository unavailable state was not exercised through the UI. Full VoiceOver navigation, Intel hardware, and older supported macOS releases were not tested for this feature.

## v0.2 distribution — 7 November 2026

The v0.2 archive contains **Twig 0.2.0, build 2**, built in release configuration with **Xcode 27.2** for both **arm64 and x86_64**. The release pipeline runs the 124-test suite, signs with Developer ID and hardened runtime, obtains Apple's notarization approval, staples the ticket, and checks Gatekeeper acceptance both before and after extracting the final ZIP. The downloadable ZIP and SHA-256 checksum are attached to [v0.2](https://github.com/lkuczborski/Twig/releases/tag/v0.2).

The signed release is a normal build: it has no `TWIG_PREVIEW` demo preference override. CI continues to exercise Xcode 27.1. Producing an Intel slice does not constitute testing on Intel hardware. VoiceOver, multiple displays, older supported macOS versions, the login approval-required state, and a full sign-out/sign-in cycle remain outside this verification.

## v0.2 application checks — 7 November 2026

All 124 tests passed again (104 core and 20 sync), with real FSEvents tests run outside the tool sandbox. Terminal’s descendant shells had the exact fixture checkout as their working directory, corroborated by Git metadata and saved open time. A Developer ID signed build installed in Applications registered and unregistered launch at login successfully; the original off state was restored. A full sign-out/reboot and an approval-required state were not exercised. The normal build discovered 22 real worktrees with existing preferences; welcome overflow scrolled correctly. See [the v0.2 feature record](features/NEXT_VERSION.md) for details.

Native checks covered keyboard navigation, exact Finder/Xcode opening, label/pin persistence, repository defaults, additional Git roots, and the scrollable welcome. The user confirmed the global shortcut from another app. See the [v0.2 feature record](features/NEXT_VERSION.md) for branch details and validation limits.

The historical v0.1 verification follows; the test counts in that record refer to the earlier release.

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

For the 1 October iteration, native preview checks confirmed that the initial visibility notification populated the real list, repository/branch rows rendered without app logos or extra labels, search narrowed the list, and the gear and per-worktree menus retained their actions. Cache and hidden-refresh behavior were checked through the scanner and refresh-state tests; menu-only checks were completed in the later glass iteration below.

The final app was rebuilt in normal menu bar mode after these checks.

### Glass, search, and Option-click iteration

The initial implementation stacked clear Liquid Glass with an ultra-thin backdrop inside `MenuBarExtra`. The user's comparison revealed that this washed out the content behind the panel. It has been replaced with native SwiftUI regular Liquid Glass hosted in a transparent AppKit panel, with no additional material on macOS 26+.

A CleanShot capture of the actual running menu panel over a controlled cyan/white/black backdrop confirmed distinct light and dark bands through the glass and rounded reflective edges. The same test in `MenuBarExtra` produced a broadly frosted surface. Temporary test windows and rendering diagnostics were removed after verification.

Repeated full-list, matching `Beatly`, and no-results `sfs` searches retained identical 360 × 435 dimensions and a search header at the top. Option-click opened the exact canonical Beatly worktree folder in Finder. The native row menu opened the SwiftUI detection-details window, the gear menu opened SwiftUI Settings, and both windows closed through their native close controls. Five consecutive status-item open/close cycles passed; search received focus on presentation and Escape dismissed the panel. A status-click race in the global event monitor was found and fixed during this check. The 75-test regression suite and build/launch checks passed.

## Practical limits

Xcode is the only supported IDE installed on this test machine. Other editors' detection, bundle matching, and launch decisions have fixture coverage; their actual installed applications were not launched. Menu-bar placement and search were checked on this display, but multiple displays, VoiceOver, older macOS versions, and Intel hardware still need release testing. Project-target detail actions and preference recovery have code/core coverage but were not exhaustively exercised through every UI path.

v0.1 distribution validation is recorded below; local development builds remain ad-hoc signed. Heuristics cannot prove a user's preferred editor; use the per-worktree override for ambiguous repositories. Recency is filesystem/Git activity plus successful opens, not Codex chat recency.
