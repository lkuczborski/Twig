# Twig v0.2

Your worktrees. One shortcut away.

Twig v0.2 makes it easier to find, recognize, and reopen your work. It brings a complete keyboard workflow, personal organization, more opening choices, a welcome experience, and support for regular Git repositories to the native macOS menu bar.

## What's new

- **Get there by keyboard.** Press Control–Shift–T from another app, search with a few letters, choose with ↑/↓, and press Return. Change or disable the global shortcut in Settings. Shift–Command–Return reopens your previous successfully opened worktree while Twig is focused.
- **Make the list yours.** Pin active worktrees, group siblings by repository, and add searchable personal labels. Long branch names use middle truncation to preserve useful endings. Labels stay in Twig and do not rename branches or folders.
- **Open it your way.** Try another supported installed editor with **Open once with…**, remember an editor for the whole repository, or open Apple's Terminal in the worktree. Individual worktree choices take priority, and each checkout resolves its own project target.
- **Bring other repositories.** Add a local checkout or bare Git repository to discover its existing worktrees alongside Codex. Duplicate checkouts are combined, unavailable sources remain visible in Settings, and removing a source leaves the repository files untouched.
- **Start with a useful welcome.** See discovered worktrees, learn the shortcut, and choose whether Twig launches at login. Reopen Welcome from Settings.

## Refinements

- The welcome worktree list scrolls, so larger collections remain reachable without expanding the window.
- Keyboard selection follows the visible order across pins and groups and scrolls the selected row into view.
- Clear section boundaries distinguish pinned worktrees, repository groups, and other checkouts.
- Fuzzy matching covers names, branches, labels, and editors; paths use literal matching to avoid unrelated results from shared prefixes.
- Existing v0.1 preferences remain compatible. Saved discovery settings, editor choices, and open history are retained, with defaults for the new options.

## Download and upgrade

[Download Twig v0.2](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip) · [SHA-256 checksum](https://github.com/lkuczborski/Twig/releases/download/v0.2/Twig-v0.2-macos-universal.zip.sha256)

**macOS 14 or later · Universal app for Apple Silicon and Intel · Developer ID signed and notarized**

Unzip the download and move **Twig.app** to **Applications**. If upgrading, quit Twig before replacing the app. Your preferences are preserved, and Welcome introduces the new features. Twig lives in the menu bar and has no Dock icon. Liquid Glass is available on macOS 26; earlier versions use native translucent material.

Twig remains local, with no account, analytics, cloud service, or conversation indexing. Automatic updates, remote PR/CI status, and worktree cleanup are future work. See the [roadmap](ROADMAP.md) and [verification notes](VERIFICATION.md) for scope and validation details.
