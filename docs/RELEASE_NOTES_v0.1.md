Twig v0.1 is the first public release: a small native macOS menu-bar app that brings recent Codex worktrees back to the right editor with one click.

### Included

- Recent worktree list with live Git branch and detached-HEAD labels.
- Automatic IDE and project-target detection, installed-editor discovery, and persistent per-worktree overrides.
- Search across projects, branches, paths, and editors.
- Option-click to open a folder in Finder, plus enclosing-folder and path-copy actions.
- Event-driven filesystem syncing and cached detection, with no scheduled polling.
- Native SwiftUI Liquid Glass on macOS 26; translucent material on earlier versions.
- A new Twig app icon and MIT license.

### Download

`Twig-v0.1-macos-universal.zip` contains **Twig.app** for Apple Silicon and Intel Macs running **macOS 14 or later**. Unzip it, move the app to Applications, and open it from there. Twig lives in the menu bar and has no Dock icon.

The release is Developer ID signed, notarized by Apple, and includes a stapled ticket. The accompanying `.sha256` file verifies the ZIP. No account or network service is required to use Twig.

### Scope

Twig shows existing local Codex worktrees. Recency comes from filesystem/Git activity and successful opens through Twig, not Codex chat activity. Project detection suggests an installed editor; use a worktree override for ambiguous projects. Automatic updates and launch at login are not included in v0.1.
