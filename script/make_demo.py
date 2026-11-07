#!/usr/bin/env python3
"""Create disposable, real Git repositories for Twig's native review build."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

parent = Path(sys.argv[1]).resolve()
parent.mkdir(parents=True, exist_ok=True)
root = Path(tempfile.mkdtemp(prefix="session-", dir=parent))
codex = root / "codex"

def git(folder, *args):
    subprocess.run(["/usr/bin/git", "-c", "user.name=Twig Demo", "-c",
                    "user.email=demo@twig.invalid", *args], cwd=folder,
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

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

atlas = repository("Atlas")
grove = repository("Grove")
website = repository("Website", swift=False)
search = worktree(atlas, "search", "feature/instant-search")
navigation = worktree(atlas, "navigation", "fix/sidebar-keyboard-navigation")
accessibility = worktree(atlas, "accessibility", "feature/voiceover-support")
design = worktree(grove, "design", "feature/native-settings")
homepage = worktree(website, "homepage", "refresh/autumn-homepage")
now = time.time() * 1000
preferences = {
    "schemaVersion": 1,
    "codexHome": str(codex),
    "hasCompletedWelcome": sys.argv[2] != "--demo-welcome",
    "pinnedWorktrees": [str(search)],
    "worktreeLabels": {str(search): "Instant search", str(design): "Settings refresh"},
    "groupByRepository": True,
    "lastOpened": {str(folder): now + 10000 - index * 1000 for index, folder in enumerate([search, navigation, accessibility, design, homepage])},
}
(root / "preferences.json").write_text(json.dumps(preferences, indent=2))
print(root)
