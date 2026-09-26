if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi
# Legacy state dir from the rsync-based version: only read now, to pick the
# authoritative side when migrating a repo that still has two real copies.
export AGENT_SYNC_DIR="$DOTFILES/agent-sync"

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_agent_sync

# Claude Code reads .claude/skills, other harnesses read .agents/skills. Instead
# of copying one into the other (which drifted, and let `rsync --delete` clobber
# edits made through the mirror), the non-authoritative side is a relative
# symlink to the authoritative one: a single set of files, nothing to sync.
# Only skills/ is linked — settings, hooks, worktrees are harness-specific.
#
# Silent unless it changes something, since agent shells source this too.

# Linked git worktrees (e.g. Claude Code's isolation worktrees under
# .claude/worktrees/<name>) are skipped: only the primary checkout is managed.
_agent_sync_is_worktree() {
  local root="$1"
  local git_dir=$(git -C "$root" rev-parse --git-dir 2>/dev/null)
  local common_dir=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)
  [[ -n "$git_dir" && -n "$common_dir" && "$git_dir" != "$common_dir" ]]
}

# Absolute path of the repo's info/exclude (worktree-safe: resolves to the
# common git dir, where `$root/.git/info/exclude` would not exist).
_agent_sync_exclude_path() {
  git -C "$1" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null
}

_agent_sync_add_exclude() {
  local root="$1" pattern="$2"
  local exclude=$(_agent_sync_exclude_path "$root")
  [[ -z "$exclude" ]] && return 0
  mkdir -p "${exclude:h}"
  grep -qxF "$pattern" "$exclude" 2>/dev/null && return 0
  echo "$pattern" >> "$exclude"
}

# Print the authoritative side ("claude" or "agents"): the one whose skills/ is
# a real directory. Empty if neither is, "both" if both are.
_agent_sync_source() {
  local root="$1"
  local c=0 a=0
  [[ -d "$root/.claude/skills" && ! -L "$root/.claude/skills" ]] && c=1
  [[ -d "$root/.agents/skills" && ! -L "$root/.agents/skills" ]] && a=1
  if (( c && a )); then echo both
  elif (( c )); then echo claude
  elif (( a )); then echo agents
  fi
}

_agent_sync_other() { [[ "$1" == "claude" ]] && echo agents || echo claude; }

# Ensure .$dst/skills is a symlink to ../.$src/skills. Refuses to replace a real
# directory — migration from a copy goes through _agent_sync_migrate.
_agent_sync_link() {
  local root="$1" src="$2"
  local dst=$(_agent_sync_other "$src")
  local link="$root/.$dst/skills" target="../.$src/skills"

  [[ -L "$link" && "$(readlink "$link")" == "$target" ]] && return 0
  if [[ -e "$link" && ! -L "$link" ]]; then
    echo "⚠ agent-sync: .$dst/skills is a real directory; run 'agent-sync-init'"
    return 1
  fi

  mkdir -p "$root/.$dst"
  ln -sfn "$target" "$link"
  _agent_sync_add_exclude "$root" "/.$dst/skills"
  echo "✓ agent-sync: linked .$dst/skills → .$src/skills"
}

# Replace the old rsync mirror of .$src with a symlink. Only deletes the mirror
# when it is byte-identical to the source, so no edit is ever discarded.
_agent_sync_migrate() {
  local root="$1" src="$2"
  local dst=$(_agent_sync_other "$src")

  if ! diff -rq "$root/.$src/skills" "$root/.$dst/skills" >/dev/null 2>&1; then
    echo "⚠ agent-sync: .$src/skills and .$dst/skills differ; reconcile them, then"
    echo "  rm -rf .$dst/skills && agent-sync-init"
    diff -rq "$root/.$src/skills" "$root/.$dst/skills" 2>&1 | sed 's/^/    /' | head -10
    return 1
  fi

  # A whole-directory mirror (.agents made by the old `cp -r`/rsync) holds stale
  # copies of settings, hooks etc. that only confuse other harnesses: drop it
  # entirely. Otherwise only replace skills/ and leave the rest alone. worktrees/
  # is ignored: the rsync version never copied nested worktrees across.
  if [[ "$dst" == "agents" ]] && \
     diff -rq -x worktrees "$root/.claude" "$root/.agents" >/dev/null 2>&1; then
    rm -rf "$root/.agents"
  else
    rm -rf "$root/.$dst/skills"
  fi
  _agent_sync_link "$root" "$src" || return 1
  echo "✓ agent-sync: migrated .$dst copy → symlink"
}

_auto_agent_sync() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ -z "$root" ]] && return 0
  _agent_sync_is_worktree "$root" && return 0

  local src=$(_agent_sync_source "$root")
  case "$src" in
    claude|agents) _agent_sync_link "$root" "$src" ;;
    both)
      # Old copy-based setup: migrate automatically when the legacy state file
      # says which side is authoritative, otherwise ask the user.
      local state_file="$AGENT_SYNC_DIR/$(basename "$root")"
      local legacy=$(cat "$state_file" 2>/dev/null)
      if [[ "$legacy" == "claude" || "$legacy" == "agents" ]]; then
        _agent_sync_migrate "$root" "$legacy"
      else
        echo "⚠ agent-sync: both .claude/skills and .agents/skills are real directories"
        echo "  Run 'agent-sync-init' to pick the authoritative one"
      fi
      ;;
  esac
  return 0
}

agent-sync-init() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  if _agent_sync_is_worktree "$root"; then
    echo "Error: $root is a linked git worktree, not a primary checkout — agent-sync skips worktrees"
    return 1
  fi

  local src=$(_agent_sync_source "$root")
  case "$src" in
    "")
      echo "Error: Neither .claude/skills nor .agents/skills found"
      return 1
      ;;
    claude|agents)
      _agent_sync_link "$root" "$src"
      ;;
    both)
      echo "Both .claude/skills and .agents/skills are real directories. Which is authoritative?"
      select src in "claude" "agents"; do
        [[ -n "$src" ]] && { _agent_sync_migrate "$root" "$src"; return; }
      done
      ;;
  esac
}

agent-sync-status() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "Not in a git repository"
    return 1
  fi

  local name=$(basename "$root")
  if _agent_sync_is_worktree "$root"; then
    echo "$name: linked git worktree — skipped by agent-sync"
    return 0
  fi

  local src=$(_agent_sync_source "$root")
  case "$src" in
    "")   echo "$name: no skills directory" ;;
    both) echo "$name: ⚠ two real skills directories — run 'agent-sync-init'"; return 1 ;;
    *)
      local dst=$(_agent_sync_other "$src")
      if [[ -L "$root/.$dst/skills" ]]; then
        echo "$name: .$dst/skills → $(readlink "$root/.$dst/skills") (authoritative = .$src)"
      else
        echo "$name: authoritative = .$src, ⚠ .$dst/skills link missing — re-enter dir or run 'agent-sync-init'"
      fi
      ;;
  esac
}
