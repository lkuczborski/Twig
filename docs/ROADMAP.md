# Twig roadmap

Twig helps you return to the right local worktree in the right editor, with understandable and overridable choices. **v0.2 is the current release.** The implemented features below are available now; future items are proposals, not delivery commitments.

## Available in v0.2

| Area | Implemented behavior |
| --- | --- |
| Keyboard workflow | Configurable global shortcut, default Control–Shift–T; fuzzy search with literal path matching; arrow-key selection in displayed order; Return to open; previous-worktree action with Shift–Command–Return. |
| Worktree organization | Pins, repository grouping by shared Git metadata, searchable personal labels, and branch names with middle truncation. Clear section boundaries distinguish pins, repository groups, and other worktrees. |
| Welcome and launch at login | A scrollable discovered-worktree list, shortcut guidance, preference-recovery access, and optional native macOS login-item controls. Welcome can be reopened from Settings. |
| Opening actions | Open once with a supported installed editor, repository editor defaults below individual worktree choices, and Apple's Terminal through directory URLs. Project targets resolve within the current checkout. |
| Regular Git repositories | Explicit checkout or bare-repository roots alongside Codex, linked-worktree discovery, canonical deduplication, saved unavailable-root status, and filesystem subscriptions for the added sources. |

The v0.1 foundation remains: live branch and detached-HEAD labels, activity ordering, automatic editor/project detection, saved worktree targets, Finder actions, path copying, event-driven syncing, manual refresh, preferences recovery, and read-only JSON diagnostics. v0.2 reads existing v0.1 preferences without requiring a reset.

The release is packaged for Apple Silicon and Intel, Developer ID signed, and notarized. Local development builds use ad-hoc signing. Native demo modes provide invented repositories and separate preferences for screenshots and review. See the [release notes](RELEASE_NOTES_v0.2.md), [architecture](ARCHITECTURE.md), and [verification notes](VERIFICATION.md) for details.

## Improve daily use

- Support custom application bundles for editors outside the built-in catalog. Open-once currently lists supported installed editors.
- Add adapters for other terminal applications after verifying their directory-opening behavior. The current action targets Apple's Terminal.
- Offer the best few detected project targets inline when a repository is ambiguous, while preserving saved editor and target choices.
- Support multiple Codex homes. Explicit Git roots are available; Codex discovery still has one configured home.
- Benchmark event latency, idle CPU/wakeups, and burst behavior on large worktree collections. Preserve inference/application caching, hidden-state coalescing, dropped-event recovery, and manual refresh.
- Offer bounded deeper scans for large monorepos with progress and cancellation. Add explicit preference migrations when a future schema requires them, and retain choices for temporarily missing paths.

Broaden validation across VoiceOver, input methods, multiple displays, older supported macOS releases, and Intel hardware. Continue exercising missing editors, unavailable repositories, stale project targets, and unreadable preferences. Installed login-item registration and removal have been checked locally; full sign-in/reboot behavior and the approval-required state remain separate validation work. Universal packaging does not substitute for Intel hardware testing.

## Optional context and integrations

- Local Git health indicators such as uncommitted changes, ahead/behind state, and last commit. Keep expensive checks off the UI path; any Git subprocesses need argument arrays, timeouts, and read-only scope.
- Pull-request links and CI state through an optional authenticated provider, with explicit network use and refresh cadence.
- Optional Codex chat association and **Open chat** through a supported integration, without requiring conversation-text indexing.
- Explicit repository actions that show what will run and where. Discovery must never execute detected project configuration automatically.

These integrations are not implemented. The complete local workflow should remain useful offline, with a clear distinction between observed local facts, remote status, and inferred associations.

## Distribution and lifecycle

- A signed automatic-update channel. Updates currently require replacing the app manually.
- A diagnostics export that removes identifying paths and branch names by default, with review before sharing.
- Worktree cleanup after reliable ownership, activity, uncommitted-file, and recovery checks exist. Start with a review flow and prefer supported archival; never silently delete checkouts.
- Versioned detection rules and regression fixtures for new IDEs and project formats, including an explanation when a rule changes an automatic suggestion.

Automatic updates and worktree cleanup are not implemented. A failed update must leave a launchable app; a failed cleanup must preserve the checkout. These features should have independent failure handling.
