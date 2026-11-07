# Opening actions

The worktree actions menu now offers three ways to open work:

- **Open in …** follows the saved worktree choice, then the repository default, project detection, the global fallback, and finally Finder.
- **Open once with…** uses an installed editor for this launch. It selects that editor's best detected project target in the current checkout and leaves both saved editor preferences unchanged.
- **Open in Terminal** opens Apple's Terminal at the checkout directory. It sends a validated directory URL to Terminal through Launch Services; it never constructs a shell command, invokes AppleScript, or executes project code.

The **Worktree editor** and **Repository editor** submenus make the preference scope explicit. A repository default follows canonical shared Git metadata, so sibling checkouts share it while unrelated repositories with the same display name remain independent. Individual worktree choices still win. Automatic removes only the choice at that scope. If a saved editor is removed, Twig reports it as unavailable rather than silently substituting another application.

Repository defaults store only an editor. Each checkout resolves its own nested project or workspace, avoiding a target path from a sibling worktree. The details window includes Terminal, editor actions, and an explanation of the current repository default. TwigInspect uses the same precedence as the GUI.

## Persistence

`repositoryEditors` is an additive schema-1 preferences field. Existing preferences decode with an empty dictionary; unsupported future schemas and corrupt files retain the existing protection against overwriting. Keys use `RepositoryIdentity.key(for:)` and values use the stable `IDEID` identifiers. One-time launches and Terminal update successful-open recency without replacing editor choices.

## Validation

On 7 November 2026, `./script/build_and_run.sh --build` built and ad-hoc signed the app without launching it. `./script/test.sh` passed **86 tests**: 72 core tests and 14 sync tests, including the real FSEvents fixtures.

Eleven new tests cover worktree/repository/detection precedence, missing editors, target containment, nested workspace selection, one-time resolution followed by the saved default, canonical repository identity and preference round trips, legacy preferences, and Terminal directory validation with spaces, quotes, shell metacharacters, Unicode, newlines, and symlinks. Files and non-file URLs are refused.

## Runtime capture checklist

Runtime inspection and screenshots are performed in the combined preview build, separately from this branch's build and fixture verification:

1. Open a row's ellipsis menu and capture **Open once with…**, **Open in Terminal**, and the two editor scopes.
2. Set a repository editor; verify a sibling uses it. Set a different worktree editor and verify that it wins only for that checkout.
3. Open once in a different installed editor, then reopen normally and confirm the saved editor still wins.
4. Open Terminal and verify its working directory equals the selected checkout, including a fixture directory containing spaces. No Automation or Accessibility permission should be requested by this action.
5. Open details to capture the repository-default explanation and Terminal action.

Only Apple's Terminal is supported by this action in this version; other terminal applications are not silently assumed to accept directory URLs.
