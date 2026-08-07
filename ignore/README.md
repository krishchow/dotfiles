# Git Exclude Management

Centralized, version-controlled `.git/info/exclude` files for each repo.

## Structure

Each file is named after the repo (e.g., `my-project`, `another-repo`).

## Usage

**Automatic**: When you `cd` into a repo, the exclude file is automatically symlinked if one exists.

Manual commands (rarely needed):

```bash
# Edit the exclude file (opens in $EDITOR)
edit-git-exclude

# Initialize exclude file for a new repo
init-git-exclude

# Manually link (usually automatic)
link-git-exclude
```

## Setup

This directory is used by `.git-exclude.zsh`, sourced from `.zshrc`.

## How It Works

The `chpwd` hook runs every time you change directories:

1. Detects if you're in a git repo
2. Checks if `$DOTFILES/ignore/$REPO_NAME` exists
3. If yes, creates symlink automatically (backs up existing file first)
4. Silent if no exclude file exists or already linked

## Workflow

1. Create exclude patterns: `init-git-exclude` (one-time per repo)
2. `cd` anywhere in the repo → automatically linked
3. Edit patterns: `edit-git-exclude`
4. Version control `ignore/` in this repo

## Benefits

- ✅ **Zero friction** — Works automatically
- ✅ **Version controlled** — Patterns survive repo deletion
- ✅ **Per-repo** — Each repo has its own patterns
- ✅ **Safe** — Backs up existing files before linking
