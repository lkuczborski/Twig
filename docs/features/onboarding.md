# Welcome and launch at login

The first launch presents a compact native welcome window with live discovery results, destination editors, a route to discovery settings, an optional launch-at-login toggle, and an Open Twig action. Completing the welcome is saved only after preferences have been written successfully. Existing version-1 preferences remain readable. The welcome can be reopened from Settings or the application menu.

Launch at login uses `SMAppService.mainApp`. The service's status is the source of truth, including a pending-approval state with a link to Login Items. Views recheck status when the application becomes active. Login registration is never enabled automatically.

Validation: development app builds successfully; preference round-trip and legacy/unknown-schema tests pass. Runtime welcome/layout capture and combined feature verification are performed on the preview integration branch. A real logout/login cycle is outside automated checks.

Manual checks: launch with fresh preferences; inspect detected worktrees; Open Twig; relaunch and confirm the welcome stays dismissed; reopen Welcome through Settings. On an installed signed build, enable/disable launch at login and confirm System Settings reflects the state.
