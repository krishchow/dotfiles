# AGENTS.md — shell dotfiles

## Architecture

- **Makefile** is the entrypoint. `make install` = link + all installers. `make link` bootstraps the `.zshrc` source line only. `make brew` = Homebrew + Brewfile only. See `make help`.
- **`DRY_RUN=1`** on any make target previews without changes.
- **`.zshrc`** sources `.env` → `.path` → `.aliases` → `.history.zsh` → `.git-exclude.zsh` → `.agent-sync.zsh` in that order. `DOTFILES` is auto-detected from `$0`.
- **Installers** live in `scripts/installers/`. Each is a bash snippet defining `check()` + `install()`, auto-discovered by `bootstrap.sh`. Prefix convention: `0X` for bootstrapping deps, `1X`+ for everything else. See `.agents/skills/add-installer/SKILL.md` for the full pattern.
- **Brewfile** manages brew formulas, casks, and npm global packages. Prefer adding things here over a new installer unless brew doesn't cover it.

## Key patterns

- **`scripts/`** is on PATH (set in `.path`). Helper scripts like `git-configure.sh` and `alias_main_to_master.sh` are callable directly.
- **`ignore/`** — per-repo `.git/info/exclude` files auto-symlinked via `chpwd` hook (`.git-exclude.zsh`). Manual commands: `init-git-exclude`, `edit-git-exclude`, `link-git-exclude`.
- **`agent-sync/`** — per-repo state files tracking whether `.claude` or `.agents` is authoritative, auto-synced on `cd` (`.agent-sync.zsh`). Manual commands: `agent-sync-init`, `agent-sync-force`, `agent-sync-status`.
- **`repo-sync/`** — launchd agent that fetches all repos under `~/projects` hourly. Installed via `make sync-install`.
- **chpwd hook pattern** — detection + match + action, silent on no-match, `return 0` not 1. See `.agents/skills/chpwd-tool/SKILL.md` for the template when creating new ones.

## Git

- `git-configure.sh` interactively configures `user.name`/`user.email` from GitHub profile. Supports `--local` or `--global` scope.
- `alias_main_to_master.sh` creates `main` as a symbolic ref alias to `master` across all repos under `~/projects`.
- Git exclude files in `ignore/` are version-controlled. Edit them with `edit-git-exclude`.
- Default branch assumed `main` in scripts (e.g., `repo-sync/update-repos.sh`).

## Environment

- macOS only. Tools: Homebrew, zsh, launchd.
- `Brewfile.lock.json` is gitignored. Secrets patterns (.env.local, *.pem, *.key, *secret*, etc.) are defensively gitignored.
- Installers are idempotent — `check()` guards against reinstall. Bootstrap runs `set -euo pipefail`.
- `repo-sync/update-repos.sh` skips repos matching `*/sync/` to avoid conflicting with the dotfiles repo itself.
