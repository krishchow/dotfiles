---
name: add-installer
description: Add a new idempotent dependency installer to scripts/installers/. Each installer defines check() + install() and auto-registers with make install. Use when the user wants to add a new tool, runtime dependency, CLI, or post-install setup step to the dotfiles install pipeline. Also use for "add a dep", "make install should also install X", or when referencing something in .zshrc/.env/.path that isn't yet covered.
---

# add-installer

Create a new installer file in `scripts/installers/`. Each file is a bash snippet sourced by `bootstrap.sh` that defines `check()` and `install()` — no boilerplate, no other changes needed.

## Installer File Template

Create `scripts/installers/<NN>-<name>.sh`:

```bash
DESCRIPTION="Human-readable name"
check() {
  # return 0 if already installed, non-zero if not
}
install() {
  # do the install (idempotent preferred, but check guards against double-run)
}
```

Prefix convention: `00`–`09` for bootstrapping deps, `10`+ for everything else. Order within the same prefix doesn't matter.

## check() Patterns

The check must be fast, cheap, and reliable. Prefer checking for the artifact the install step creates, not intermediate state.

| Install method | Good check | Bad check |
|----------------|-----------|-----------|
| CLI tool | `command -v foo &>/dev/null` | `which foo` (slower, may fail) |
| Shell script/manager | `[[ -s "$HOME/.foo/foo.sh" ]]` | checking env vars |
| macOS .app | `[[ -d "/Applications/Foo.app" ]]` | `mdfind Foo` (slow) |
| git repo cloned | `[[ -d "$HOME/.foo/.git" ]]` | `git -C ... status` (slow) |
| npm global package | `npm list -g --depth=0 2>/dev/null \| grep -q foo` | running the tool itself |
| pip/uv package | `uv pip show foo &>/dev/null` | `pip list` then grep (wasteful) |
| Config/hook initialized | `git config --global --get foo.bar &>/dev/null` | checking file existence |
| Rust crate | `command -v foo &>/dev/null` (cargo install --list is slow) | |

## install() Patterns

Pick the right install method. Always use the official/supported way.

| Method | Template |
|--------|----------|
| curl pipe bash | `curl -fsSL "<url>" \| bash` |
| curl pipe bash (version pinned) | `curl -o- <url> \| bash` |
| git clone | `git clone --depth 1 <repo> "$HOME/.foo"` |
| npm global | `npm install -g foo` |
| cargo install | `cargo install foo` |
| uv tool install | `uv tool install foo` |
| macOS .app (dmg, manual) | warn the user — prefer cask in Brewfile |
| pipx | `pipx install foo` |
| manual download + move | `curl -fsSLo /tmp/foo <url> && sudo mv /tmp/foo /usr/local/bin/` |
| post-brew init | `foo setup` or `foo install` (tool's native init command) |

## Workflow

When asked to add a new dependency:

1. **Identify the dep** — what tool/runtime/config does the user need? Is it referenced in `.zshrc`, `.env`, `.path`, or `.aliases`?
2. **Find the install method** — check the tool's official docs. Prefer brew cask/formula if available (add to Brewfile instead). Use installer scripts for things brew doesn't cover.
3. **Write the check** — what proves it's already installed? Must be fast.
4. **Write the install** — the official install command.
5. **Pick a prefix** — `0X` if other installers depend on it, `1X`–`9X` otherwise.
6. **Create the file** — `scripts/installers/<NN>-<name>.sh`
7. **No other changes needed** — `run_installers` auto-discovers it.

## When NOT to Add a New Installer

- **It's a brew formula/cask** → add to `Brewfile` instead.
- **It's a VS Code extension** → add to `Brewfile` under `vscode`.
- **It's a macOS App Store app** → not automatable; mention in docs.
- **It's a one-off script/config** → doesn't belong in the install pipeline.
- **It requires sudo** → flag it for manual review.

## Existing Installers (for reference)

Look at `scripts/installers/` for working examples:

| File | What it does |
|------|-------------|
| `00-homebrew.sh` | Installs Homebrew via official script, evals shellenv |
| `01-brewfile.sh` | Runs `brew bundle --no-lock` (idempotent) |
| `10-nvm.sh` | Installs nvm via official install script |
| `20-maestro.sh` | Installs Maestro mobile testing tool via curl |
| `30-git-lfs-init.sh` | Post-brew: runs `git lfs install` |

## Example: Adding a New CLI Tool

User says: "Add `bun` to make install."

```bash
# scripts/installers/20-bun.sh
DESCRIPTION="bun (JavaScript runtime)"
check() { command -v bun &>/dev/null; }
install() { curl -fsSL https://bun.sh/install | bash; }
```

(The curl pipe bash install script is the official bun installer.)

## Example: Adding a Post-Install Init Step

User says: "After brew installs pyenv, I need pyenv init to be configured."

This doesn't need an installer — `.path` already runs `eval "$(pyenv init - zsh)"` on every shell start. If a tool needs a one-time init (like `git lfs install`), that's what the installer is for.

## Edge Cases

- **Install depends on another installer** — use a higher prefix number (e.g., a tool needing git goes after `00-homebrew.sh`).
- **Install requires a specific shell** — prefer bash or sh. If zsh is required, note it but keep the installer as bash (bootstrap.sh is bash).
- **Install produces no binary** — check for the artifact it creates (config file, directory, etc.).
- **User already has a different version** — the check should detect any functional version. Don't be picky about versions unless the user asks.
- **Install fails silently** — the `set -euo pipefail` in bootstrap.sh catches errors. But add `|| true` for known non-critical failures.
