# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Central dotfiles and shell environment for macOS (zsh). Bootstraps zsh config, Homebrew, runtime managers (nvm, pyenv), CLI tools, launchd agents, and per-project automation hooks for git repos under `~/projects`. There is no build/test/lint step — changes are verified by sourcing the shell config or running the relevant script/installer directly.

## Commands

```sh
make install       # Full setup: link ~/.zshrc source line + run all installers
make link           # Bootstrap ~/.zshrc source line only
make brew           # Homebrew + Brewfile only (formulas/casks/npm globals)
make unlink         # Remove the source line from ~/.zshrc
make freeze         # Snapshot installed brew packages into Brewfile (respects .brewignore)
make deepfreeze     # freeze + nvm/pyenv version pins + global git config extras + shell-rc migration + custom launchd agents
make sync-install   # Install the repo-sync launchd agent (hourly repo fetch)
make sync-uninstall # Uninstall the repo-sync launchd agent
make launchd-install   # Install custom launchd agents captured under launchd/ by deepfreeze
make launchd-uninstall # Uninstall those custom launchd agents
make dry-run        # Preview `make install` without making changes
make help           # List targets
```

`DRY_RUN=1` works on any target to preview without changes, e.g. `make install DRY_RUN=1`.

To test a single installer without running the whole pipeline, source `scripts/bootstrap.sh`'s pattern manually: `source scripts/installers/10-nvm.sh && check` (or `install`).

## Architecture

- **Makefile** is the entrypoint; it just shells out to `scripts/bootstrap.sh {link,brew,unlink,install,freeze,deepfreeze,sync-install,sync-uninstall,launchd-install,launchd-uninstall}`.
- **`.zshrc`** sources, in order: `.env` → `.path` → `.aliases` → `.history.zsh` → `.git-exclude.zsh` → `.agent-sync.zsh` → `.runtime-version.zsh`. `DOTFILES` is auto-detected from `${0:A:h}` so the repo works regardless of clone location.
- **Installers** (`scripts/installers/*.sh`) are bash snippets each defining `check()` + `install()` + `DESCRIPTION`, auto-discovered and sourced by `bootstrap.sh`. Naming convention: `0X-*` for bootstrapping deps (homebrew, brewfile), `1X+` for everything else (`10-nvm.sh`, `11-pyenv.sh`, `12-git-include.sh`, `20-maestro.sh`, `30-git-lfs-init.sh`). `check()` must be fast/cheap and idempotent-safe — `run_installers` skips `install()` when `check()` passes. See `.agents/skills/add-installer/SKILL.md` (mirrored at `.claude/skills/add-installer/SKILL.md`) for the full pattern and decision table (brew formula vs. installer vs. not automatable).
- **Brewfile** manages brew formulas, casks, and npm global packages — prefer adding here over a new installer unless Homebrew doesn't cover the tool. `make freeze` overwrites it with the live `brew bundle dump` state (taps/formulae/casks/npm only — mas and vscode entries are excluded); a tracked `.brewignore` (see `.brewignore.example`) lists package names to permanently exclude from freezes.
- **`.git-exclude.zsh`** implements a `chpwd` hook: on every `cd` into a git repo, it symlinks `ignore/<repo-name>` (version-controlled in this repo) to that repo's `.git/info/exclude`, backfilling from an existing local exclude file if present. Manual commands: `init-git-exclude`, `link-git-exclude`, `edit-git-exclude`.
- **`.agent-sync.zsh`** implements a second `chpwd` hook: on entering a repo that has `.claude/` and/or `.agents/` directories, it keeps them mirrored (rsync, `--delete`, excludes `.git`) based on a per-repo "authoritative source" state file in `agent-sync/<repo-name>`. If a repo has only one of the two dirs, that one becomes authoritative and gets copied to create the other; if both exist with no state file, it prompts via `agent-sync-init`. Manual commands: `agent-sync-init`, `agent-sync-force`, `agent-sync-status`.
- **`repo-sync/`** — launchd agent (`repo-sync.plist.template`, installed via `make sync-install`) that runs `update-repos.sh` hourly to fetch all repos under `~/projects`. It skips paths matching `*/sync/` to avoid conflicting with this repo itself, and assumes `main` as the default branch.
- **`make deepfreeze`** extends `make freeze` with four more capture steps (all in `scripts/bootstrap.sh` unless noted): `freeze_runtime_versions` pins nvm's resolved default Node version to `.nvmrc` and pyenv's global version to `.python-version` (both tracked at repo root; skipped when unset/`system`) — `scripts/installers/10-nvm.sh` and the new `scripts/installers/11-pyenv.sh` install+pin those on a fresh machine. `freeze_git_config` captures `git config --global --list` entries not already tracked into a new tracked `git/gitconfig` file (excludes `user.*`/`github.user`, `filter.lfs.*`, and anything credential/token/secret-shaped); `scripts/installers/12-git-include.sh` wires it into `~/.gitconfig` via git's native `include.path`. `scripts/deepfreeze-shell.sh` scans `~/.zshrc`/`~/.zprofile`/`~/.zshenv`/`~/.bash_profile`/`~/.bashrc` for `alias`/`PATH` lines not yet in `.aliases`/`.path`, auto-migrates new ones (dedup via literal/`$HOME`-normalized substring match), and only *reports* env-var exports, eval/source lines, and already-covered duplicates — it never writes to `.env` or edits the source rc files. `freeze_launchd_agents` generalizes the `repo-sync` pattern: scans `~/Library/LaunchAgents/*.plist`, skips known vendor prefixes (`com.apple.`, `com.google.`, etc.) and anything already referencing `$DOTFILES`, and copies the rest into a tracked `launchd/*.plist.template` dir, installable/uninstallable via `make launchd-install`/`launchd-uninstall` (opt-in, not part of `make install`, same as `sync-install`/`sync-uninstall`).
- **`.runtime-version.zsh`** implements a third `chpwd` hook: on every `cd`, it walks up from `$PWD` to `/` looking for `.nvmrc`/`.python-version`. If an `.nvmrc` is found upward it runs `nvm use --silent` (reverting to `nvm use default --silent` otherwise); if a `.python-version` is found it exports `PYENV_VERSION` from `pyenv version-name` (unsetting it otherwise, since pyenv shims already resolve per-invocation and this just surfaces the active version to the current shell/prompt). Both halves are guarded (`typeset -f nvm`, `command -v pyenv`) so it's a silent no-op where those tools aren't loaded.
- **New chpwd-style tools** should follow the detection → match → action pattern established by `.git-exclude.zsh` (see `.agents/skills/chpwd-tool/SKILL.md`): cheap detection, silent `return 0` on no-match, idempotent action, centralized per-project state under `$DOTFILES/<tool>/<repo-name>`, sourced last from `.zshrc`.

## Key conventions

- `git-configure.sh` (in `scripts/`, on `PATH` via `.path`) interactively sets `user.name`/`user.email` from the GitHub profile; supports `--local` (default) or `--global`.
- `alias_main_to_master.sh` creates `main` as a symbolic-ref alias to `master` across all repos under `~/projects` — the convention elsewhere in this repo (and `repo-sync`) is to assume `main` as the default branch.
- Secrets are defensively gitignored (`.env.local`, `*.pem`, `*.key`, `*secret*`, etc.); `Brewfile.lock.json` is also gitignored. `.env` itself is tracked but Claude Code's own permission settings deny reading it — `deepfreeze`'s scanners and `freeze_git_config`'s credential/token/secret keyword filter are both designed to never touch it or write secret-shaped values into tracked files.
- `deepfreeze`-managed tracked files: `.nvmrc`, `.python-version` (runtime version pins), `git/gitconfig` (global git config extras), `launchd/*.plist.template` (custom launchd agents, `__HOME__`/`__DOTFILES__`-templated like `repo-sync.plist.template`). The launchd vendor-prefix skip-list lives in `LAUNCHD_VENDOR_PREFIXES` in `scripts/bootstrap.sh`.
- `bootstrap.sh` runs under `set -euo pipefail`; installers should be written accordingly (idempotent, non-fatal failures explicitly guarded with `|| true`).
- macOS-only — relies on Homebrew, zsh, and launchd.
