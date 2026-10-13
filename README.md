# shell

Central dotfiles and shell environment for macOS and Linux.

Bootstraps zsh, Homebrew, runtime managers (nvm, pyenv), CLI tools, launchd agents, and per-project automation hooks for git repos under `~/projects`.

## Quick start

```sh
make install   # Link ~/.zshrc + run installers supported on this machine
```

Preview before making changes:

```sh
make dry-run
```

## What's included

- **zsh bootstrap** — single source line in `~/.zshrc` wiring up env, path, aliases, and hooks
- **Homebrew + Brewfile** — formulas, casks, and npm packages
- **Installers** — idempotent setup for tools brew doesn't cover (nvm, Maestro, git-lfs)
- **chpwd hooks** — auto-link per-repo `.git/info/exclude` files and symlink `.agents/skills` ↔ `.claude/skills` on `cd` (one set of skill files for every harness)
- **repo-sync** — launchd agent that fetches all repos under `~/projects` hourly

## Common tasks

| Task | Command |
|------|---------|
| Configure git identity | `git-configure.sh` (local) or `git-configure.sh --global` |
| Add a git exclude pattern | `edit-git-exclude` |
| Link / migrate agent skills dir | `agent-sync-init` (`agent-sync-status` to check) |
| Alias `main` → `master` everywhere | `alias_main_to_master.sh` |
| Install repo-sync agent | `make sync-install` |
| Add a new dependency | See `make help` or `.agents/skills/add-installer/SKILL.md` |

## Ghostty terminal support

`make install` preconfigures the machine running it to recognize `xterm-ghostty`.
The installer compiles the bundled Ghostty 1.3.1 definition into `~/.terminfo`
when the terminal definition is missing. Ghostty itself does not need to be
installed on that machine, and no network download or sudo is needed.

To install just the terminal definition on a Linux SSH host, run **on that host**:

```sh
cd ~/projects/shell
make terminfo
```

On Linux, `make install` skips Homebrew and the Brewfile (including casks)
automatically. It still links Zsh configuration and runs the other installers.
Steps needing `pyenv` or `git-lfs` skip with a message if those commands are
missing; install those tools with your system package manager and rerun setup.
Both targets support `DRY_RUN=1`.
If `make` is not installed, use `bash scripts/bootstrap.sh install` for full
setup, or `bash scripts/bootstrap.sh terminfo` for just terminal support.

The installer requires `tic` and `infocmp` (`ncurses-bin` on Debian), skips an
existing usable definition, and is safe to repeat. Reconnect SSH or run
`exec zsh` after installing it.

The tracked source is `terminfo/xterm-ghostty.terminfo`, with its upstream MIT
license beside it. To refresh it from an installed Ghostty release, export with
`infocmp -x xterm-ghostty` and update the version in the source header.
See [Ghostty's terminfo guidance](https://ghostty.org/docs/help/terminfo).
