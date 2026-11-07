# Worktree details

**Status: implemented on the development branch, unreleased.** The combined build, automated checks, and native preview checks described below have passed. This feature is not included in the v0.2 download.

## Row behavior

Rows keep their existing two-line layout, with the branch identity preserved. Secondary context adds the useful project type for the target that will open, the last successful open through Twig when recorded, and local Git indicators. The destination editor's installed icon appears beside the row; Finder and unavailable editors have appropriate fallback presentation. Lower-priority context yields when space is tight, while tooltips and accessibility descriptions preserve fuller details.

Project type comes from existing detection and the resolved launch target, rather than guessing from the editor icon. **Opened … ago** uses Twig's saved successful-open timestamp, including successful open-once actions. It is independent of filesystem/Git activity used for ordering and is not a Codex chat timestamp. A checkout with no successful-open record has no age label.

Git indicators distinguish changed files, unresolved file conflicts, and commits ahead/behind the locally known upstream. A missing upstream does not imply zero remote divergence. No fetch occurs, so counts reflect the local refs available at the time of the read. Failed, unsupported, or incomplete checks show unavailable status rather than a clean result.

## Local status boundaries

The status reader runs separately from discovery and editor inference. `Sources/TwigCore/Git/GitStatusReader.swift`, `GitStatusParser.swift`, and `BoundedGitProcess.swift` handle bounded read-only Git commands and their machine-readable results. `Sources/Twig/Services/WorktreeGitStatusStore.swift` caches and schedules them.

- At most four checkout reads run concurrently, off the UI path.
- Each checkout read defaults to an aggregate two-second timeout and 1 MiB output budget across its commands. Positive finite timeout overrides cannot exceed 60 seconds.
- Filesystem/Git events invalidate affected results. All work is cancelled when every Twig view is hidden; pending changes are processed when a view returns. There is no idle polling timer, and manual refresh remains available.
- Checks do not fetch, run project code, or execute repository filters, hooks, or filesystem-monitor commands. Tracked filters that would affect the comparison yield unavailable status; unused filter configuration alone does not. This behavior has core-test coverage; the filtered-repository UI state has not been exercised.
- Nested submodule uncommitted and untracked contents are excluded. A changed gitlink commit still counts.

Repository discovery continues to read metadata directly without invoking Git. Status is a separate best-effort enrichment; unavailable status does not remove a checkout or prevent opening it.

## Demo fixtures

Generate an isolated preview session with real Git state:

```sh
./script/build_and_run.sh --demo-details
```

To generate the fixtures without building or launching Twig:

```sh
python3 script/make_demo.py dist/demos --demo-details
```

The command prints the generated session directory. Pass that directory to a preview-enabled Twig build with `--twig-demo-root`. The normal `--demo` and `--demo-welcome` modes retain their five sample checkouts. Their saved grouping preference opens the Project view; the header switch can change to Activity.

| Sample checkout | Project | Saved last opened | Actual Git state |
| --- | --- | --- | --- |
| Atlas / Instant search | Swift package | 90 seconds ago | Clean |
| Atlas / fix/sidebar-keyboard-navigation | Swift package | 11 minutes ago | One modified source file and one untracked file |
| Atlas / feature/voiceover-support | Swift package | 65 minutes ago | Clean, one commit ahead of local `main` |
| Grove / Settings refresh | Swift package | 26 hours ago | One unresolved file conflict, one commit ahead and one behind local `main` |
| Website / refresh/autumn-homepage | Node.js package | No record | Clean |

“Last opened” is seeded in the session's disposable Twig preferences; Git facts come from actual repositories, branches, commits, working files, and an unresolved merge index. Editor icons and project types are resolved by the running app from these project files and the applications installed on the Mac.

The fixtures live entirely below the supplied output parent, normally `dist/demos`. They use no remote or network operation. Git subprocesses discard inherited Git environment settings, bypass system/global config, disable hooks, signing, and filesystem-monitor commands, and use an empty local template. The generator does not alter the user's real Twig preferences. Remove a generated session directory when it is no longer needed.

Preference keys use Foundation-compatible macOS paths: temporary aliases such as `/private/tmp` are stored as `/tmp`, while ordinary `/Users` paths remain unchanged. Pins, labels, and successful-open ages therefore match the canonical IDs returned by discovery when the preview worktree itself lives in a temporary directory.

The generator verifies its clean, changed, ahead/behind, and conflict cases before printing the session path. Existing modes can be checked with:

```sh
python3 script/make_demo.py dist/demos --demo
python3 script/make_demo.py dist/demos --demo-welcome
```

## Verification status

Fixture generation has been checked for all three demo modes, including with unrelated Git environment variables supplied. The details fixtures were inspected with real Git: the changed-file counts, ahead/behind counts, and unresolved conflict match the table above. Successful-open fixture timestamps are in the past, and Website has no recorded open.

The combined development build passed. The complete baseline run passed 130 core tests, including 16 Git tests, plus 22 sync tests. After adding transport-denial and `info/exclude` routing coverage, focused reruns passed 17 Git tests, 20 routing tests, and 3 real FSEvents tests. Those runs cover the final inventory of 154 tests (131 core and 23 sync); they were not one final full-suite run.

Native preview checks confirmed the table's Git counts, Swift and JS / TS project types, Xcode/Finder icons, successful-open ages, pins, labels, branch identity, search, and Down-arrow selection. The details view showed the exact saved open date and complete Git counts. Adding an untracked `LiveRefresh.md` file updated the row from two changed files to three through the watcher; adding it to the common `.git/info/exclude` changed the count back to two automatically, without manual refresh. Review fixes for Git exclude/attribute invalidation, linked-index scope, and coalesced ancestor/subdirectory events have automated coverage, with the live exclude-file case also confirmed in the native UI.

Full VoiceOver navigation, Intel hardware, older supported macOS releases, and the unavailable-status UI for a repository with tracked filters remain unverified. These development checks do not change the public v0.2 release. The [verification record](../VERIFICATION.md) carries the run accounting and remaining limits.
