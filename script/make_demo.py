#!/usr/bin/env python3
"""Create disposable, real Git repositories for Twig's native review build."""
import json
import os
from datetime import datetime, time as day_time, timedelta
from pathlib import Path
import subprocess
import sys
import tempfile
import time

if len(sys.argv) not in (2, 3):
    raise SystemExit("Usage: make_demo.py OUTPUT_PARENT [--demo|--demo-welcome|--demo-details|--demo-activity]")
mode = sys.argv[2] if len(sys.argv) == 3 else "--demo"
if mode not in ("--demo", "--demo-welcome", "--demo-details", "--demo-activity"):
    raise SystemExit(f"Unknown demo mode: {mode}")

parent = Path(sys.argv[1]).resolve()
parent.mkdir(parents=True, exist_ok=True)
root = Path(tempfile.mkdtemp(prefix="session-", dir=parent))
codex = root / "codex"
template = root / "empty-git-template"
template.mkdir()
# Explicitly discard inherited Git location/configuration variables. The sample
# repositories must never use a user's index, hooks, signing, templates, or network.
git_environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
git_environment.update({
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_ATTR_NOSYSTEM": "1",
    "GIT_TERMINAL_PROMPT": "0",
})

def preference_path(folder):
    """Match WorktreePath.key's Foundation spelling for macOS private aliases."""
    resolved = Path(folder).resolve()
    if sys.platform == "darwin":
        # Python realpath expands /tmp to /private/tmp, while Foundation's
        # standardizedFileURL.resolvingSymlinksInPath() uses the public spelling.
        # Limit this to the real macOS aliases; ordinary /Users paths stay intact.
        for public in (Path("/tmp"), Path("/var"), Path("/etc")):
            private = Path("/private") / public.relative_to("/")
            if public.resolve() != private:
                continue
            try:
                return str(public / resolved.relative_to(private))
            except ValueError:
                pass
    return str(resolved)

def git(folder, *args, expected_exit=0):
    command = [
        "/usr/bin/git", "-c", "user.name=Twig Demo", "-c", "user.email=demo@twig.invalid",
        "-c", "core.hooksPath=" + os.devnull,
        "-c", "core.attributesFile=" + os.devnull,
        "-c", "core.fsmonitor=false", "-c", "commit.gpgsign=false",
        "-c", "tag.gpgsign=false", "-c", "protocol.allow=never",
        "-c", "init.templateDir=" + str(template), *args,
    ]
    result = subprocess.run(command, cwd=folder, env=git_environment,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != expected_exit:
        raise subprocess.CalledProcessError(result.returncode, command, result.stdout, result.stderr)
    return result.stdout

def repository(name, swift=True):
    folder = root / "repositories" / name
    folder.mkdir(parents=True)
    git(folder, "init", "-q", "-b", "main")
    if swift:
        (folder / "Package.swift").write_text(
            '// swift-tools-version: 6.0\nimport PackageDescription\n'
            f'let package = Package(name: "{name}", targets: [.executableTarget(name: "{name}")])\n')
        source = folder / "Sources" / name
        source.mkdir(parents=True)
        (source / "main.swift").write_text(f'print("Hello from {name}")\n')
    else:
        (folder / "package.json").write_text(json.dumps({"name": name.lower(), "private": True}))
        (folder / "README.md").write_text(f"# {name}\nA sample project for Twig previews.\n")
    git(folder, "add", ".")
    git(folder, "commit", "-qm", "Create demo project")
    return folder

def worktree(repo, bucket, branch):
    folder = codex / "worktrees" / bucket / repo.name
    folder.parent.mkdir(parents=True, exist_ok=True)
    git(repo, "worktree", "add", "-q", "-b", branch, str(folder))
    return folder

def activity_dates(now):
    """Use local calendar days, including the local UTC offset on each date."""
    today = now.date()
    start_of_day = datetime.combine(today, day_time())
    elapsed = (now - start_of_day).total_seconds()
    week_start = today - timedelta(days=today.weekday())
    # On Monday there is no earlier day in the current week. Keep accessibility
    # in Today in that case, rather than inventing a weekday section.
    earlier_this_week = today - timedelta(days=min(2, today.weekday()))
    previous_thursday = week_start - timedelta(days=4)
    # A previous-month entry must also predate Last week, even near a month boundary.
    earlier_month = min(today.replace(day=1) - timedelta(days=7), week_start - timedelta(days=8))
    return (
        now - timedelta(seconds=min(90, elapsed / 3)),
        now - timedelta(seconds=min(11 * 60, elapsed * 2 / 3)),
        min(datetime.combine(earlier_this_week, day_time(11)), start_of_day + timedelta(seconds=elapsed / 4))
        if earlier_this_week == today else datetime.combine(earlier_this_week, day_time(11)),
        datetime.combine(previous_thursday, day_time(11)),
        datetime.combine(earlier_month, day_time(11)),
    )

def backdate_worktree(folder, date):
    """Change fixture metadata only; never follow a path outside this session."""
    timestamp = date.timestamp()

    def stamp(path):
        path.resolve().relative_to(root)
        if path.is_symlink():
            raise ValueError("Demo timestamps must not follow symbolic links")
        os.utime(path, (timestamp, timestamp), follow_symlinks=False)

    def stamp_tree(directory):
        for child in directory.rglob("*"):
            stamp(child)
        stamp(directory)

    # Discovery considers source directories, the .git pointer, the worktree's
    # HEAD/index/HEAD log, and the branch ref in the shared Git directory.
    git_directory = Path((folder / ".git").read_text().removeprefix("gitdir: ").strip())
    if not git_directory.is_absolute():
        git_directory = folder / git_directory
    git_directory = git_directory.resolve()
    git_directory.relative_to(root)
    common_directory = (git_directory / (git_directory / "commondir").read_text().strip()).resolve()
    common_directory.relative_to(root)
    reference = (git_directory / "HEAD").read_text().removeprefix("ref: ").strip()
    stamp_tree(folder)
    stamp_tree(git_directory)
    for path in (common_directory / reference, common_directory / "logs" / reference):
        if path.exists():
            stamp(path)

atlas = repository("Atlas")
grove = repository("Grove")
website = repository("Website", swift=False)
search = worktree(atlas, "search", "feature/instant-search")
navigation = worktree(atlas, "navigation", "fix/sidebar-keyboard-navigation")
accessibility = worktree(atlas, "accessibility", "feature/voiceover-support")
design = worktree(grove, "design", "feature/native-settings")
homepage = worktree(website, "homepage", "refresh/autumn-homepage")

if mode in ("--demo-details", "--demo-activity"):
    # Two actual changes: one modified tracked source and one untracked file.
    with (navigation / "Sources" / "Atlas" / "main.swift").open("a") as source:
        source.write('print("Keyboard navigation in progress")\n')
    (navigation / "NavigationNotes.md").write_text("# Navigation\nReview focus order and arrow-key behavior.\n")

    # A local upstream provides ahead/behind facts without a remote or fetch.
    git(accessibility, "branch", "--set-upstream-to=main")
    (accessibility / "Accessibility.md").write_text("# Accessibility\nDescribe every worktree action for VoiceOver.\n")
    git(accessibility, "add", "Accessibility.md")
    git(accessibility, "commit", "-qm", "Document VoiceOver actions")

    # Both branches change the same source line. Leave a real merge conflict for
    # the app to read from the index rather than manufacturing indicator values.
    git(design, "branch", "--set-upstream-to=main")
    (grove / "Sources" / "Grove" / "main.swift").write_text('print("Settings from main")\n')
    git(grove, "add", ".")
    git(grove, "commit", "-qm", "Update settings on main")
    (design / "Sources" / "Grove" / "main.swift").write_text('print("Settings from the redesign")\n')
    git(design, "add", ".")
    git(design, "commit", "-qm", "Redesign the settings greeting")
    git(design, "merge", "--no-edit", "main", expected_exit=1)

    # Fail early if a Git/toolchain change no longer produces the intended cases.
    assert not git(search, "status", "--porcelain=v1").strip()
    assert len(git(navigation, "status", "--porcelain=v1").splitlines()) == 2
    assert git(accessibility, "rev-list", "--left-right", "--count", "HEAD...@{upstream}").split() == ["1", "0"]
    assert git(design, "rev-list", "--left-right", "--count", "HEAD...@{upstream}").split() == ["1", "1"]
    assert git(design, "diff", "--name-only", "--diff-filter=U").splitlines() == ["Sources/Grove/main.swift"]

now = time.time() * 1000
last_opened = {
    preference_path(folder): now + 10000 - index * 1000
    for index, folder in enumerate([search, navigation, accessibility, design, homepage])
}
if mode == "--demo-details":
    last_opened = {
        preference_path(search): now - 90 * 1000,
        preference_path(navigation): now - 11 * 60 * 1000,
        preference_path(accessibility): now - 65 * 60 * 1000,
        preference_path(design): now - 26 * 60 * 60 * 1000,
        # Website intentionally has no successful-open record.
    }
if mode == "--demo-activity":
    dates = activity_dates(datetime.now())
    folders = [search, navigation, accessibility, design, homepage]
    last_opened = {
        preference_path(folder): date.timestamp() * 1000
        for folder, date in zip(folders[:-1], dates[:-1])
    }
    # Do this only after every Git verification command: an index refresh during
    # setup would otherwise move an old fixture back into Today's activity section.
    for folder, date in zip(folders, dates):
        backdate_worktree(folder, date)
preferences = {
    "schemaVersion": 1,
    "codexHome": preference_path(codex),
    "hasCompletedWelcome": mode != "--demo-welcome",
    "pinnedWorktrees": [] if mode == "--demo-activity" else [preference_path(search)],
    "worktreeLabels": {preference_path(search): "Instant search", preference_path(design): "Settings refresh"},
    "groupByRepository": mode != "--demo-activity",
    "lastOpened": last_opened,
}
if mode == "--demo-activity":
    preferences["sortOrder"] = "activity"
(root / "preferences.json").write_text(json.dumps(preferences, indent=2))
print(root)
