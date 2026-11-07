# Worktree organization

Twig keeps pinned worktrees at the top of the menu and groups other checkouts by their shared Git repository. Repository groups only get a heading when at least two unpinned checkouts share that repository; single checkouts retain the compact two-line row. Within a group, the branch becomes the primary title. Grouping can be disabled in the gear menu.

The row actions menu provides **Pin worktree / Unpin worktree** and **Edit label…**. Label editing opens the existing detail window, with a personal-label field, Save/Clear actions, and a pin checkbox. Labels only affect Twig; branch names and checkout directories are untouched. A labeled row keeps the repository and branch as context. Full branch strings reach SwiftUI's middle truncation, preserving distinctive endings when room runs out.

Search includes personal labels. Search results remain flat and keep their supplied match order. Pins and repository grouping apply to the unfiltered list. `TwigStore.visibleItems` follows the actual displayed section order and is the integration point for keyboard navigation.

Preferences keep schema version 1 and add optional `pinnedWorktrees`, `worktreeLabels`, and `groupByRepository` fields. Old files load with no pins/labels and grouping enabled. Pins and labels use canonical checkout paths and are retained when a checkout temporarily disappears. Unknown future schema versions still block saves.

Repository identity uses the canonical common Git directory, with Git directory and checkout-path fallbacks. Equal repository display names do not merge unrelated projects. The organization helper can adopt the opening-actions branch's shared `RepositoryIdentity.key(for:)` at integration.

## Verification

- `./script/build_and_run.sh --build` passed; it staged and ad-hoc signed the app without launching it.
- `./script/test.sh` passed all 82 tests, including real FSEvents fixtures. Seven new tests cover pins without duplicates, same-name repository separation, stable group order, flat search order, missing metadata, symlink identity, and preference round-trip/removal.
- `git diff --check` passed.
- The root agent owns running-app checks and screenshot/video capture after integration.

## UI checks for the combined preview

1. Populate two or more checkouts from one repository and another independent repository. Verify group headings and branch titles.
2. Pin one checkout through its row menu; verify it appears once in Pinned and remains pinned after restarting Twig.
3. Choose Edit label…, enter “Login redesign”, save, and search for “redesign”. Verify the row preserves repository/branch context and opens the original target.
4. Clear the label and unpin; verify the original title/order returns.
5. Toggle Group by repository off and on. Use the keyboard feature's arrows to confirm visual order matches navigation order.
6. Check a long branch name and detached HEAD, plus two unrelated repositories with the same folder name.
