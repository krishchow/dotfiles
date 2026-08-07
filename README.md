# shell

Central dotfiles and shell environment for macOS.

Bootstraps zsh, Homebrew, runtime managers (nvm, pyenv), CLI tools, launchd agents, and per-project automation hooks for git repos under `~/projects`.

## Quick start

```sh
make install   # Full setup: link ~/.zshrc + run all installers
```

Preview before making changes:

```sh
make dry-run
```

## What's included

- **zsh bootstrap** — single source line in `~/.zshrc` wiring up env, path, aliases, and hooks
- **Homebrew + Brewfile** — formulas, casks, and npm packages
- **Installers** — idempotent setup for tools brew doesn't cover (nvm, Maestro, git-lfs)
- **chpwd hooks** — auto-link per-repo `.git/info/exclude` files and sync `.claude` ↔ `.agents` directories on `cd`
- **repo-sync** — launchd agent that fetches all repos under `~/projects` hourly

## Common tasks

| Task | Command |
|------|---------|
| Configure git identity | `git-configure.sh` (local) or `git-configure.sh --global` |
| Add a git exclude pattern | `edit-git-exclude` |
| Set authoritative agent dir | `agent-sync-init` |
| Alias `main` → `master` everywhere | `alias_main_to_master.sh` |
| Install repo-sync agent | `make sync-install` |
| Add a new dependency | See `make help` or `.agents/skills/add-installer/SKILL.md` |
