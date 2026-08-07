---
name: chpwd-tool
description: Create zsh scripts/tools that auto-trigger actions when you cd into a directory matching criteria. Use the chpwd hook pattern (as in .git-exclude.zsh) for per-project auto-setup, symlinking, env switching, or any context-aware shell automation. Use when the user wants to create a new shell tool, a cd hook, per-directory automation, or follows the "detect on cd + act" pattern.
---

# chpwd-tool

Create zsh scripts that trigger actions when you `cd` into a directory matching criteria. Follows the pattern established in `.git-exclude.zsh`.

## Pattern Layers

Every tool built with this pattern has these three layers:

1. **Detection** — `add-zsh-hook chpwd` fires a function on every directory change
2. **Match** — A cheap detection check identifies if the current directory matches your criteria (is it a git repo? a Node project? has a specific file?)
3. **Action** — If criteria match, perform the action (symlink, env setup, source a file, print a hint)

Optionally: manual commands (`init`, `link`, `edit`) that let users bypass the auto-hook.

## Skeleton Template

When generating a new tool, start here and customize the marked sections:

```zsh
if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi

### CONFIG — paths/settings unique to this tool ###
export MYTOOL_DIR="$DOTFILES/mytool-data"

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_mytool

_auto_mytool() {
  ### DETECTION — cheap check for directory "identity" ###
  local id=$(some_detection_cmd 2>/dev/null)
  if [[ -z "$id" ]]; then
    return 0
  fi

  ### ACTION — act on the match ###
  do_something "$id"
}

# ---- Manual commands (optional) ----

mytool-init() {
  local id=$(some_detection_cmd 2>/dev/null)
  if [[ -z "$id" ]]; then
    echo "Not in a matching directory"
    return 1
  fi
  # create config/data for this project
}

mytool-link() {
  local id=$(some_detection_cmd 2>/dev/null)
  if [[ -z "$id" ]]; then
    echo "Not in a matching directory"
    return 1
  fi
  # force link/activate for current project
}

mytool-edit() {
  local id=$(some_detection_cmd 2>/dev/null)
  if [[ -z "$id" ]]; then
    echo "Not in a matching directory"
    return 1
  fi
  ${EDITOR:-vim} "$MYTOOL_DIR/$id"
}
```

## Detection Patterns

Use the right detection for the context. Prefer the cheapest check that uniquely identifies the directory.

| Criteria | Detection |
|----------|-----------|
| Git repo root | `git rev-parse --show-toplevel 2>/dev/null` |
| Git repo name | `basename "$(git rev-parse --show-toplevel 2>/dev/null)"` |
| Node project | `[[ -f package.json ]]` |
| Python project | `[[ -f pyproject.toml \|\| -f setup.py ]]` |
| Rust project | `[[ -f Cargo.toml ]]` |
| Go module | `go list -m 2>/dev/null` |
| Has marker file | `[[ -f .toolname ]]` |
| Dir matches name | `[[ "$(basename "$PWD")" == "thing" ]]` |
| Parent dir check | `[[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/.env" ]]` |
| Git remote | `git remote get-url origin 2>/dev/null` |

## Action Patterns

| Goal | Implementation |
|------|----------------|
| Symlink a per-project file | `ln -sf "$MYTOOL_DIR/$id" "$PWD/.target"` |
| Export an env var | `export TOOL_CONFIG="$MYTOOL_DIR/$id"` |
| Source a script | `source "$MYTOOL_DIR/$id/env.zsh"` |
| Switch runtime version | `nvm use`, `pyenv local`, `rustup override set` |
| Print a hint | `echo "Run tool-init to set up"` |
| Backfill existing data | Copy local file to central store (see git-exclude for example) |

## Design Rules

These come from what works (and what breaks) in `.git-exclude.zsh`:

- **Detection must be cheap.** No network calls, no large file reads. If detection is slow, every `cd` feels sluggish.
- **Silent on no-match.** `return 0` (not `return 1`), no error output. Non-matches are the common case.
- **Redirect stderr.** Detection commands should `2>/dev/null` so they don't spew errors when not in the right context.
- **Idempotent.** Re-entering the same directory should not redo work. Track state if needed.
- **State-aware output.** Print messages only on first match or state change, not on every `cd` into the same project.
- **Centralized storage.** Per-project data lives in `$DOTFILES/<tool>/<repo-name>` or similar, not scattered in repos.
- **Source in .zshrc last.** The tool script should be self-contained; users just add `source "$DOTFILES/.toolname.zsh"` to `.zshrc`.

## Workflow

When a user asks you to create a `chpwd`-style tool:

1. **Understand the trigger** — what directory criteria should fire? What identifies the right context?
2. **Understand the action** — what should happen when criteria match? Once? Every time? Only on first entry?
3. **Decide on manual commands** — does the user need `init`, `link`, `edit`, or other manual commands?
4. **Pick a storage path** — where does per-project data live? Default: `$DOTFILES/<tool-name>/`
5. **Generate the script** — follow the skeleton, fill in detection and action, write to `$DOTFILES/.toolname.zsh`
6. **Remind to source** — tell the user to add `source "$DOTFILES/.toolname.zsh"` to `.zshrc`
7. **Ask if they want to test** — suggest `exec zsh` to reload, then `cd` into a matching directory

## Example: Auto-activate Python venv

User says: "I want to auto-activate a venv when I cd into a Python project."

```zsh
if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi

_auto_venv() {
  if [[ -f .venv/bin/activate ]]; then
    if [[ -z "$VIRTUAL_ENV" || "$VIRTUAL_ENV" != "$PWD/.venv" ]]; then
      source .venv/bin/activate
      echo "venv activated"
    fi
  elif [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate 2>/dev/null
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_venv
```

## Example: Auto-link project-specific .env

User says: "I keep .env files in ~/envs/ per project. Auto-symlink when I cd into a git repo."

```zsh
export ENV_DIR="$DOTFILES/envs"

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_env

_auto_env() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then return 0; fi

  local name=$(basename "$root")
  local env="$ENV_DIR/$name"
  local target="$root/.env"

  if [[ ! -f "$env" ]]; then return 0; fi
  if [[ -L "$target" ]]; then return 0; fi
  if [[ -f "$target" ]]; then return 0; fi

  ln -sf "$env" "$target"
  echo "Linked .env for $name"
}
```

## Edge Cases to Handle

- **Not in a repo/project** — detection returns empty, `return 0` silently
- **First-time entry** — no per-project data exists yet; print a hint about `init`
- **Symlink already correct** — check before recreating (`[[ -L "$target" && "$(readlink "$target")" == "$src" ]]`)
- **Existing non-symlink file** — backup before overwriting (as git-exclude does with `mv "$target" "$target.backup"`)
- **Deleted projects** — stale data files are fine; they just won't get linked until the repo is visited again
