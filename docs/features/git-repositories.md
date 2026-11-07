# Regular Git repositories

**Add Repository…** is available in the gear menu, empty state, and Settings. Choose a main checkout, a linked worktree, or a bare repository. Repository discovery reads Git's administrative metadata directly and never invokes Git, a shell, or repository code. The separate worktree-status feature uses bounded, local read-only Git commands for change/conflict/ahead/behind indicators; it does not fetch or run project code. Those status indicators are included in v0.2 build 3.

Selecting a normal checkout discovers the main checkout and all extant registered linked worktrees. Selecting a linked worktree follows its common-directory pointer to discover the same set. Bare repositories expose their linked checkouts, with no fabricated main worktree, including when the bare directory is literally named `.git` or its parent is selected. A bounded read of the local `core.bare` setting distinguishes that layout; config includes and commands are not evaluated. Relative `.git`, `commondir`, and reciprocal `gitdir` pointers are resolved from their correct locations. Stale and misdirected registrations are skipped with warnings. Pointer reads are bounded and reject symlinked metadata files.

Explicit roots remain alongside automatic Codex discovery. `WorktreeCatalog` combines sources using canonical checkout paths, so a Codex checkout registered in an added repository appears once. Unrelated repositories with the same display name retain distinct identities. Existing project inference, opening behavior, and editor overrides apply to all results.

Settings lists each saved root, its path, and local-checkout count. Missing or unreadable roots stay configured and show an actionable error with **Check Again** and a remove control. Removing a root only removes Twig's discovery configuration; it never deletes a repository or a worktree. `repositoryRoots` is an additive, optional schema-1 preference field; legacy preferences default to no explicit roots.

Filesystem subscriptions include every discovered checkout folder, explicit roots or their nearest existing ancestors, and Git administrative directories. Valid registered checkout paths that are temporarily missing remain in `RepositoryRootStatus.unavailableWorktreeFolders` and are also watched through their existing ancestors. Restoring an external checkout therefore triggers discovery without requiring any change to the common Git registry. Content edits outside Codex invalidate only the affected project's inference. Common-directory worktree registrations trigger discovery and subscription updates, including a bare repository's first worktree. Git object churn and build/dependency content remain ignored. An unavailable root's reappearance is observed through its ancestor; hidden windows retain the existing deferred-scan behavior. Settings participates in visibility tracking so repository status stays current while that window is open.

For a nonstandard separate Git directory that records no main-checkout location, add the main checkout itself to include it. Twig does not search unrelated folders to guess its location. Standard `.git` repositories and linked worktrees are covered directly.

## Verification

- `./script/build_and_run.sh --build` passed and ad-hoc signed the staged bundle without launching it.
- Full test suite: 95 tests pass, including real FSEvents fixtures. Added coverage exercises main/linked entry points, detached HEAD, relative pointers, bare repositories (including `.git` names), missing roots and recovery without registry changes, stale/misdirected metadata, canonical source deduplication, equal repository names, scanner cache retention/pruning, persisted unavailable roots, outside-Codex content watching, registry changes, and missing-root subscription recovery.
- `git diff --check` passed.
- Running-app verification and media capture are handled by the root agent after integration.

## Integration notes

- `WorktreeScanner.scan(codexHome:invalidatedWorktrees:repositoryRoots:)` keeps the old parameters and defaults `repositoryRoots` to `[]`.
- `ScanSnapshot.repositoryStatuses` supplies per-root status.
- `ChangeRouting` adds defaulted `repositoryRoots` and `repositoryGitDirectories`; pass status common directories even when a bare repository has zero worktrees.
- `TwigStore` adds `repositoryRoots`, `repositoryStatuses`, `isAddingRepository`, `chooseRepository()`, `addRepository(_:) async`, and `removeRepository(_:)`.
- `RepositoryRootsSection` is a reusable native SwiftUI Form section.

## UI checks for the combined preview

1. Add a normal repository with two linked worktrees; verify all three local checkouts appear once.
2. Add one linked checkout from that repository; verify no duplicate rows and usable per-root status.
3. Add a bare repository with a linked checkout; verify the bare directory itself is not an openable row.
4. Move an added root temporarily, verify the unavailable state and retained configuration, then restore it and Check Again.
5. Create/remove a linked worktree externally while Twig is open; verify discovery follows the common registry and editor detection is reused for unchanged checkouts.
6. Remove the repository from Twig and verify every file remains on disk.
