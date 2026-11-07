# Twig roadmap

Twig helps you return to the right local worktree in the right editor, with understandable and overridable choices. **v0.1 is the published release.** The features below marked as preview are implemented on the local `codex/next-preview` branch; they have not been published as a new release. Future items are proposals, not delivery commitments.

## Stable v0.1

The release includes the native menu-bar list, live Git branch and detached-HEAD labels, activity ordering, search, event-driven syncing, manual refresh, a configurable Codex home, project/editor detection, installed-editor discovery, saved worktree choices, project-target selection, Finder actions, path copying, preferences recovery, and read-only JSON diagnostics.

The downloadable v0.1 app is Developer ID signed, notarized, and packaged for Apple Silicon and Intel. Local development builds use ad-hoc signing. The [architecture](ARCHITECTURE.md) and [verification notes](VERIFICATION.md) describe the released foundation.

## Implemented in the next-version preview

| Feature worktree | Implemented behavior |
| --- | --- |
| Keyboard workflow | Configurable global shortcut, default Control–Shift–T; fuzzy search with literal path matching; arrow-key selection in displayed order; Return to open; previous-worktree action. |
| Worktree organization | Pins, repository grouping by shared Git metadata, personal labels, searchable labels, and branch names with middle truncation. Explicit section boundaries distinguish Pinned, repository groups, and other worktrees. |
| Welcome and launch at login | Welcome with a scrollable discovered-worktree list, shortcut guidance, recovery access, and optional native macOS login-item controls. |
| Opening actions | Open once with an installed editor, repository editor defaults below individual worktree choices, and Apple's Terminal through directory URLs. Project targets resolve within the current checkout. |
| Regular Git repositories | Explicit checkout or bare-repository roots alongside Codex, linked-worktree discovery, canonical deduplication, saved unavailable-root status, and expanded filesystem subscriptions. |

The five branches remain separate worktrees and are combined on `codex/next-preview` for interaction checks. Demo modes create invented Git projects and separate preferences for screenshots and review. See [NEXT_VERSION.md](features/NEXT_VERSION.md) for the branch manifest, observed UI behavior, and validation limits. Feature implementation does not imply release readiness.

## Finish preview validation and release preparation

- Complete the combined regression suite and record the exact result in the preview manifest. The user has confirmed that physical Control–Shift–T opens Twig from another application.
- Confirm Terminal's actual working directory after launch, including paths with spaces and special characters. URL dispatch and fixture validation alone do not prove Terminal's resulting directory.
- Exercise launch-at-login enable/disable, approval-required state, and sign-in behavior using an appropriately installed, signed app. The preview's login registration has not been toggled for capture.
- Check VoiceOver, input methods, multiple displays, older supported macOS releases, and Intel hardware. Preserve useful errors for missing editors, unavailable repositories, stale project targets, and unreadable preferences.
- Review native screenshots and interaction captures, then separately perform universal packaging, Developer ID signing, notarization, and release verification before any publication.

## Additional daily-use improvements

- Select custom application bundles for unsupported editors. Open-once currently lists supported installed editors.
- Add adapters for other terminal applications after verifying their directory-opening behavior. The preview's terminal action targets Apple's Terminal.
- Offer the best few detected project targets inline when a repository is ambiguous, while preserving the saved editor and target decisions.
- Support multiple Codex homes. Explicit Git roots are implemented; Codex discovery still has one configured home.
- Benchmark event latency, idle CPU/wakeups, and burst behavior on large worktree collections. Retain inference/application caching, hidden-state coalescing, dropped-event recovery, and manual refresh.
- Offer bounded deeper scans for large monorepos with progress and cancellation. Introduce explicit schema migrations when future preference changes require them, and retain choices for temporarily missing paths.

## Optional context and integrations

- Local Git health indicators such as uncommitted changes, ahead/behind state, and last commit. Keep expensive checks off the UI path; any Git subprocesses need argument arrays, timeouts, and read-only scope.
- Pull-request links and CI state through an optional authenticated provider, with explicit network use and refresh cadence.
- Optional Codex chat association and “Open chat” through a supported integration, without requiring conversation-text indexing.
- Explicit repository action extensions that show what will run and where. Discovery must never execute detected project configuration automatically.

These remain future work. The complete local workflow should remain useful offline, with a clear distinction between observed local facts, remote status, and inferred associations.

## Distribution and lifecycle work

- A signed automatic-update channel. Automatic updates are not implemented in this preview.
- A diagnostics export that removes identifying paths and branch names by default, with review before sharing.
- Worktree cleanup only after reliable ownership, activity, uncommitted-file, and recovery checks exist. Start with a review flow and prefer supported archival; never silently delete checkouts.
- Versioned detection rules and regression fixtures for new IDEs and project formats, including an explanation when a rule changes an automatic suggestion.

A failed update must leave a launchable app. A failed cleanup must preserve the checkout. Update delivery and cleanup should have independent failure handling.
