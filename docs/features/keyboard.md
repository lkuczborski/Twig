# Keyboard workflow

Twig registers **Control–Shift–T** to open from any application. Settings → Keyboard records a different combination, disables it, or restores the default. Registration uses Carbon hotkeys, without requesting Accessibility access or monitoring typing in other apps. A conflicting registration reports an error and retains the saved choice. The default avoids Control–Option–Space, which macOS uses for [switching input sources](https://support.apple.com/en-euro/guide/mac-help/mchlp1406/27/mac/27).

Closing or hiding Settings, or switching to another application, cancels an unfinished recording and immediately restores the saved shortcut. This observes the actual AppKit window because Settings content is retained after close.

Within Twig, **↑ / ↓** select a worktree and keep it visible, **Return** opens it, and **Escape** dismisses the panel. The selected row is highlighted and its destination editor appears in the footer. Navigation does not interfere with native action menus or input-method text composition.

Search accepts partial, case-insensitive, accent-insensitive words and subsequences. For example, `atl keynav` can match the Atlas repository's `feature/keyboard-navigation` branch. Exact and contiguous matches rank ahead of fuzzy matches; activity order breaks ties. Every space-separated query token must match one of the repository, branch, path, or editor fields. Paths use contiguous matching only, so common absolute-directory prefixes cannot create unrelated fuzzy results.

**Shift–Command–Return**, also available as **Open Previous Worktree** in the gear menu, alternates between the two most recently opened existing worktrees. With one successful open it reopens that checkout. Only successful Twig opens enter this history; missing checkouts are skipped. The selection is separate from the details window's selected worktree.

## Validation

- `./script/build_and_run.sh --build` passes with Xcode's Swift 6 toolchain targeting macOS 14 and later.
- `./script/test.sh` passes all **82 tests**, including seven new checks for fuzzy ranking, multi-field queries, path-prefix false positives, accents and repeated characters, stable selection, previous-worktree history, and old/disabled shortcut preferences. The real FSEvents tests passed outside the sandbox.
- Runtime UI verification and screenshots are performed on the combined preview branch. Suggested checks: invoke the global shortcut from another app; type a fuzzy query; move beyond the visible viewport with arrows; Return opens the selected result; Escape dismisses; native row menus retain their own navigation; record/reset/disable the shortcut; open A then B, then use Shift–Command–Return to return to A.
- The combined preview recorded Control–Shift–T without a registration error. The user confirmed physical invocation from another app; targeted UI-automation key injection is not the evidence for that confirmation.

## Integration

`TwigStore.highlightedID` is distinct from `selectedID`. If repository sections reorder the list, use their flattened `visibleItems` in `highlightedItem`, `reconcileHighlight()`, and `moveHighlight(by:)`. Include personal worktree labels in the `WorktreeSearch.score` fields when the organization feature is combined. Search results should retain their ranked order while filtering.
