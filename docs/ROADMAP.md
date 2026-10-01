# Twig roadmap

The product goal is to make an existing worktree one click away in the right editor, while keeping every automatic choice understandable and overridable. Priorities below are proposed; they are not implemented features or delivery dates.

## 0. Current MVP

The implementation includes a compact native menu bar list, live Git branch/detached-HEAD labels, activity ordering, search, event-driven syncing and manual refresh, configurable Codex home, ranked project/editor detection, installed-app discovery, one-click opening, persistent worktree overrides, project-target selection, Finder actions, path copying, preferences recovery, and read-only JSON diagnostics.

The core is separated from UI and application launching, with fixture tests for its discovery, detection, resolution, and persistence behavior. See [ARCHITECTURE.md](ARCHITECTURE.md) for current bounds and limitations; validation results are recorded separately. The local app bundle is a development build, not a notarized release with automatic updates.

## 1. Make daily use faster

| Feature | Benefit / completion criterion |
| --- | --- |
| Global keyboard shortcut and full list navigation | Open Twig, search, move selection, and launch without a mouse; shortcuts remain configurable and accessible. |
| Launch at login | An explicit setting backed by the macOS login-item API, with clear enabled/disabled state. |
| Pins and repository grouping | Keep active worktrees visible and distinguish several checkouts of the same project without relying on hover text. |
| “Open once with…” and custom apps | Try another installed application without changing the saved default; select an app bundle for unsupported editors. Keep URL-based launching. |
| Terminal actions | Open the chosen terminal in the worktree through a dedicated adapter, with tested handling of spaces and special path characters. |
| Richer ambiguity controls | Show the best few project targets inline and distinguish editor choice from project-target choice. Preserve saved decisions across refreshes. |

Complete this phase with keyboard/VoiceOver checks and clear behavior for removed worktrees, missing editors, and stale saved targets.

## 2. Scale discovery and preferences

- Benchmark event latency, idle CPU/wakeups, and burst behavior against representative large worktree collections. FSEvents, hidden-state coalescing, project-inference caching, and application-catalog caching are already implemented.
- Refine catalog and activity rescanning if profiling shows a need; preserve dropped-event recovery and manual full refresh.
- Support multiple Codex homes and explicitly added Git roots through separate discovery sources. Keep unavailable roots visible as actionable status rather than silently removing user configuration.
- Add repository-wide editor defaults, with an explicit precedence order: worktree choice, repository choice, project inference, global fallback. Let the user choose when a worktree decision should be shared.
- Offer scan-depth controls and a “scan deeper” action for large monorepos, with progress and cancellation. Keep conservative defaults and make incomplete results visible.
- Add schema migrations and careful retention of preferences for missing paths, so a temporarily disconnected drive does not erase choices.

Complete this phase when repeated openings use cached results promptly, filesystem events cannot trigger scan storms, and fixture benchmarks cover large directories, inaccessible roots, moves, and cancellations.

## 3. Add useful context

- Git health indicators: dirty files, ahead/behind state, detached status, and last commit. Run any Git subprocesses with argument arrays, timeouts, and explicit read-only scope; do not put expensive status calls on the UI path.
- Pull request links and CI state through an optional authenticated provider. Keep the local-only workflow complete, and make network access and refresh cadence explicit.
- Optional Codex thread association and “Open chat.” Prefer a supported integration; treat local metadata schemas as versioned adapters. Association should be opt-in and should not require indexing conversation text.
- Optional action extensions for repository-specific workflows. Preview actions and their working directory; never execute detected project configuration just because it exists.

Complete this phase with graceful offline behavior and a clear distinction between locally observed facts, remote status, and inferred associations.

## 4. Release and lifecycle management

- Developer ID signing, notarization, reproducible release packaging, and signed updates before broad distribution.
- A diagnostics export that defaults to removing identifying paths and branch names, plus explicit user review before sharing.
- Worktree cleanup only after reliable ownership and activity checks exist. Start with a review screen that shows the exact checkout, dirty/untracked state, active use, and recovery path. Favor Codex-managed archival where supported; never silently delete worktrees.
- Versioned detection rules and regression fixtures for new IDEs and project formats, with an explanation when a rule changes the automatic editor choice.

Cleanup and update delivery should have independent failure handling: an unsuccessful cleanup must preserve the checkout, and a failed update must leave a launchable app.
