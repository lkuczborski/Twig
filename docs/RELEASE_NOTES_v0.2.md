# Twig v0.2

Your worktrees. One shortcut away.

Twig v0.2 brings faster navigation, useful project and Git context, personal organization, and more opening choices to the native macOS menu bar.

**Refreshed on 7 November 2026 — version 0.2.0, build 3.** This replaces the earlier v0.2 download with worktree details, Activity date sections, and menu-bar refinements. If you already downloaded v0.2, download it again and replace the app to get these changes.

## What's new

- **Pick up recent work.** Activity groups worktrees into Today, weekdays from this week, Last week, Earlier this month when applicable, and older months. Prefer alphabetical project groups? Choose **Activity / Project** in **Settings → Worktree list → Sort by**. The choice is saved, pins stay at the top, and Project keeps recent work first within each group. Activity reflects observed source/Git changes and successful opens through Twig.
- **Recognize each checkout.** Two-line rows preserve branch identity while adding project type, recorded last-opened time, and the destination editor's icon. Context adapts to the available width; tooltips and **Project & detection details** retain the full information.
- **See local Git status.** Spot changed files, unresolved conflicts, and commits ahead or behind the locally known upstream. Checks run in the background and refresh on filesystem changes. Twig does not fetch; counts reflect existing local refs, and failed checks show unavailable status instead of implying a clean checkout.
- **Get there by keyboard.** Press Control–Shift–T from another app, search with a few letters, choose with ↑/↓, and press Return. Change or disable the global shortcut in Settings. Shift–Command–Return reopens your previous successfully opened worktree while Twig is focused.
- **Make the list yours.** Pin active worktrees and add searchable personal labels. Long branch names use middle truncation to preserve useful endings. Labels stay in Twig and do not rename branches or folders.
- **Open it your way.** Try another supported installed editor with **Open once with…**, remember an editor for the whole repository, or open Apple's Terminal in the worktree. Individual worktree choices take priority, and each checkout resolves its own project target.
- **Bring other repositories.** Add a local checkout or bare Git repository to discover its existing worktrees alongside Codex. Duplicate checkouts are combined, unavailable sources remain visible in Settings, and removing a source leaves its files untouched.
- **Start with a useful welcome.** See discovered worktrees in a scrollable list, learn the shortcut, and choose whether Twig launches at login. Reopen Welcome from Settings.

## Refinements

- Gray section labels, counts, and extra spacing make longer lists easier to scan. Sorting lives in Settings, and the permanent keyboard-hint footer is removed; all shortcuts still work.
- The panel aligns to the left or right edge of its menu-bar icon, within screen bounds. On macOS 27, clicking the icon keeps its native selection visible while the panel is open, including during search.
- Keyboard selection follows the displayed order across pins and groups and scrolls the selected row into view.
- Fuzzy matching covers names, branches, labels, and editors. Search results remain ranked by relevance; paths use literal matching to avoid unrelated results from shared prefixes.
- Saved discovery settings, editor choices, pins, labels, and open history are retained. The former grouping preference migrates to Activity or Project; new preferences default to Activity. Existing v0.1 preferences remain compatible.

## Download and upgrade

[Download Twig v0.2](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip) · [SHA-256 checksum](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip.sha256)

**macOS 14 or later · Universal app for Apple Silicon and Intel · Developer ID signed and notarized**

Quit Twig, unzip the download, and move **Twig.app** to **Applications**, replacing the previous copy. Your preferences are preserved. Twig lives in the menu bar and has no Dock icon. Liquid Glass is available on macOS 26 and later; earlier versions use native translucent material. Updates are installed manually.

Twig remains local, with no account, analytics, cloud service, or conversation indexing. Automatic updates, remote PR/CI status, and worktree cleanup are future work. See the [roadmap](https://github.com/lkuczborski/Twig/blob/v0.2/docs/ROADMAP.md) and [verification notes](https://github.com/lkuczborski/Twig/blob/v0.2/docs/VERIFICATION.md) for scope and validation details.
