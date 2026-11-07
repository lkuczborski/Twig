# Twig roadmap

Twig helps you return to the right local worktree in the right editor, with understandable and overridable choices. **v0.2 is the current release.** The refreshed download is **0.2.0, build 3**. Its shipped features are listed separately from future proposals; future items are not delivery commitments.

## Available in v0.2

| Area | Implemented behavior |
| --- | --- |
| Keyboard workflow | Configurable global shortcut, default Control–Shift–T; fuzzy search with literal path matching; arrow-key selection in displayed order; Return to open; previous-worktree action with Shift–Command–Return. |
| Worktree organization | Pins, searchable personal labels, and branch names with middle truncation. Settings selects date-grouped Activity or alphabetical Project groups; pins stay first, recent work leads within a project, and search remains ranked by relevance. |
| Worktree context | Project type, recorded successful-open age, destination-editor icon, and local Git changed-file/conflict/ahead/behind indicators. Secondary context adapts to the available width. |
| Menu-bar presentation | Gray section labels and spacing, a compact search-and-list layout, and panel alignment to the icon within screen bounds. On macOS 27, native expanded-interface sessions retain the clicked icon’s selection during search. |
| Welcome and launch at login | A scrollable discovered-worktree list, shortcut guidance, preference-recovery access, and optional native macOS login-item controls. Welcome can be reopened from Settings. |
| Opening actions | Open once with a supported installed editor, repository editor defaults below individual worktree choices, and Apple's Terminal through directory URLs. Project targets resolve within the current checkout. |
| Regular Git repositories | Explicit checkout or bare-repository roots alongside Codex, linked-worktree discovery, canonical deduplication, saved unavailable-root status, and filesystem subscriptions for the added sources. |

The v0.1 foundation remains: live branch and detached-HEAD labels, activity ordering, automatic editor/project detection, saved worktree targets, Finder actions, path copying, event-driven syncing, manual refresh, preferences recovery, and read-only JSON diagnostics. v0.2 reads existing v0.1 preferences without requiring a reset.

The release is packaged for Apple Silicon and Intel, Developer ID signed, and notarized. Local development builds use ad-hoc signing. Native demo modes provide invented repositories and separate preferences for screenshots and review. See the [release notes](RELEASE_NOTES_v0.2.md), [architecture](ARCHITECTURE.md), and [verification notes](VERIFICATION.md) for details.

## Worktree details and Activity view

The refreshed v0.2 adds project type, successful-open age, and a destination-editor icon while preserving two-line rows and branch identity. Local Git indicators report changed files, conflicts, and ahead/behind counts against locally known upstream refs, without fetching.

An Activity / Project choice in Settings → Worktree list selects recent work grouped by date or alphabetical project groups. Activity uses Today, weekday names from this week, Last week, Earlier this month when applicable, and month headings for older work. Gray headings and extra spacing distinguish sections without separator lines. The menu has no permanent sort control or keyboard-hint footer. Pins remain first; project groups keep recent work first, and search remains ranked by relevance. The selected view persists across launches.

Status reads run independently from discovery, with at most four concurrent checkouts and a default two-second / 1 MiB budget per checkout. Filesystem events invalidate results; work is cancelled when all Twig views are hidden. Unsupported or failed status reads remain unavailable rather than implying a clean worktree.

The combined build, automated regressions, and native preview checks have passed with the limits recorded in the [feature notes](features/WORKTREE_DETAILS.md) and [verification record](VERIFICATION.md). Full VoiceOver navigation, Intel hardware, older supported macOS versions, and filtered-repository UI checks remain outside the completed verification.

## Improve daily use

- Support custom application bundles for editors outside the built-in catalog. Open-once currently lists supported installed editors.
- Add adapters for other terminal applications after verifying their directory-opening behavior. The current action targets Apple's Terminal.
- Offer the best few detected project targets inline when a repository is ambiguous, while preserving saved editor and target choices.
- Support multiple Codex homes. Explicit Git roots are available; Codex discovery still has one configured home.
- Benchmark event latency, idle CPU/wakeups, and burst behavior on large worktree collections. Preserve inference/application caching, hidden-state coalescing, dropped-event recovery, and manual refresh.
- Offer bounded deeper scans for large monorepos with progress and cancellation. Add explicit preference migrations when a future schema requires them, and retain choices for temporarily missing paths.

Broaden validation across VoiceOver, input methods, multiple displays, older supported macOS releases, and Intel hardware. Continue exercising missing editors, unavailable repositories, stale project targets, and unreadable preferences. Installed login-item registration and removal have been checked locally; full sign-in/reboot behavior and the approval-required state remain separate validation work. Universal packaging does not substitute for Intel hardware testing.

## Optional context and integrations

- Last-commit context, beyond the local changed-file/conflict/ahead/behind indicators available in v0.2. Keep any additional reads bounded and off the UI path.
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
