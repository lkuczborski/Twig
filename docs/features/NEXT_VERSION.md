# v0.2 feature and verification record

This record describes the five feature worktrees integrated into **Twig v0.2** on **7 November 2026**. The combined branch was merged into `main`; the release is version **0.2.0**, build **2**. See the [release notes](../RELEASE_NOTES_v0.2.md) and [distribution verification](../VERIFICATION.md) for release status and checks.

## Feature branches and worktrees

| Feature | Branch | Managed worktree | Notes |
| --- | --- | --- | --- |
| Keyboard workflow | `codex/keyboard` | `twig-keyboard/Twig` | [Shortcut, search, selection, and previous worktree](keyboard.md) |
| Organization | `codex/organization` | `twig-organization/Twig` | [Pins, groups, and personal labels](organization.md) |
| Onboarding | `codex/onboarding` | `twig-onboarding/Twig` | [Welcome and launch at login](onboarding.md) |
| Opening actions | `codex/opening-actions` | `twig-opening-actions/Twig` | [Open once, repository defaults, and Terminal](opening-actions.md) |
| Git repositories | `codex/git-repositories` | `twig-git-repositories/Twig` | [Additional roots and linked checkouts](git-repositories.md) |
| Combined preview | `codex/next-preview` | `twig-next-preview/Twig` | All features plus integration fixes and the capture harness |

Worktree paths in the table are relative to the local managed worktree directory. The original `main` checkout is the final build location. Feature branches preserve the separate implementation history; `main` contains the integrated release.

## Run the native preview

From the combined preview checkout:

```sh
./script/build_and_run.sh --demo
./script/build_and_run.sh --demo-welcome
```

`--demo` opens the menu content in an inspectable native preview window. `--demo-welcome` also shows the first-run experience. Both use the actual SwiftUI views, store, discovery, editor resolution, and launching services. They compile with `TWIG_PREVIEW`; the demo preference override is absent from normal builds.

The script creates fresh, real Git fixture repositories under `dist/demos/session-*`, with invented Atlas, Grove, and Website projects, branches, and labels. It supplies a separate preferences file and Codex discovery root for that session. No personal project content, chat text, or credentials are copied into these fixtures. The demo still queries real installed editors and macOS login-item status; those operating-system controls are not simulated.

To run against your normal saved Twig preferences, use `./script/build_and_run.sh`. To build without launching, use `./script/build_and_run.sh --build`. Preview bundles are locally ad-hoc signed and are not release artifacts.

## Combined behavior

- **Control–Shift–T** is the configurable default global shortcut. Arrow keys follow the displayed order across pins and groups. Return opens the selected checkout, Escape dismisses, and Shift–Command–Return reopens the previous successful checkout.
- Fuzzy matching covers names, branches, editor names, and personal labels. Absolute paths use literal matching to avoid unrelated fuzzy results from a common directory prefix.
- Pins are distinct from repository groups. Singleton repositories appear under Recent or Other worktrees when a heading is needed to avoid ambiguity. Labels affect only Twig.
- Welcome lists discovered worktrees in a bounded scroll area, shows shortcut guidance, and provides access to Settings when preferences need recovery. Launch at login uses macOS's own status and approval flow.
- Saved opening precedence is worktree choice, repository choice, project inference, global fallback, then Finder. Open-once leaves saved editor choices intact. Terminal receives a validated directory URL rather than a generated shell command.
- Added Git roots join automatic Codex discovery. Shared canonical checkout identities prevent duplicates; unavailable configured roots retain their settings. Removing a source never removes its repository files.

## Observed native UI checks

The following checks were observed in the actual running combined preview:

- Welcome's subtitle and scrollable discovered-worktree list remain readable, including all available sample rows.
- Search narrows results, including fuzzy terms, without unrelated matches from absolute paths. All five initial sample worktrees render, and search results retain repository and branch context.
- Arrow-key navigation updates the visible selected row. Return opened the exact selected fixture folder in Finder.
- The shortcut recorder accepted a custom combination and updated the displayed preference. The user confirmed that physical **Control–Shift–T opens Twig from another application**.
- The personal label “Keyboard polish” saved successfully. The Pin checkbox updated persisted preferences.
- Setting the repository editor to Xcode changed the launch explanation to “Your editor choice for this repository.”
- Open once with Xcode opened the exact Atlas `feature/instant-search` checkout and its `Package.swift`. The resulting preferences retained empty worktree overrides and repository-editor choices.
- Completing Welcome saved its completion flag and opened the actual menu-bar panel. Final search, selection, and action-menu captures also use that panel, without the preview-window title bar.
- Installed signed-app login registration changed macOS status to enabled; unregister returned it to disabled. The original off setting was restored. The initial not-found state no longer incorrectly tells users to move an already-installed app.
- The normal build read existing preferences, discovered 22 real worktrees, and scrolled its full welcome list. Existing editor choices and open history were retained.
- **Add Repository…** used the native folder picker. Adding the sample Atlas root found its four checkouts and merged linked checkouts already present through Codex discovery.

These checks use synthetic repositories and isolated Twig preferences. The original internal capture gallery is retained locally under ignored `dist/feature-previews`. The public 35-second intro uses clean native window captures with CleanShot framing; its sanitized Remotion source is versioned in [`media/intro`](../../media/intro) and the MP4 is attached to v0.2. Per-feature notes are linked above.

## Combined regression result

The final combined regression run (after the login guidance correction, outside the tool sandbox for FSEvents access) passed **124 tests**: **104 core tests in 11 suites** and **20 sync tests in two suites**, including the real FSEvents fixtures. This includes the follow-up bare-repository and missing-linked-checkout restoration fixes. Counts are from the combined run, not the sum of feature-branch reports.

## Validation limits

- Global shortcut registration reported no error, and the user verified hardware invocation from another app. Targeted UI-automation key injection alone did not activate the Carbon hotkey; it is not the evidence for that confirmation.
- Terminal’s actual working directory was verified through read-only process metadata: both descendant shells had the exact sample checkout as cwd; Git confirmed `fix/sidebar-keyboard-navigation`, and the saved open timestamp matched Terminal startup. No Terminal UI inspection was used. Special-character directory handling has core fixture coverage; live dispatch used an ordinary fixture path.
- Installed Developer ID signed-app registration and removal passed. macOS enabled the item immediately, so an approval-required state was not exercised. A full logout/reboot was not performed during this active session.
- VoiceOver, multiple displays, older supported macOS versions, and Intel hardware remain separate validation work. Universal packaging, signing, and notarization are covered by the v0.2 distribution workflow.

Automatic updates, remote CI/PR status, and worktree cleanup remain future work. The [release workflow](../RELEASING.md) owns distribution packaging and publishing.
