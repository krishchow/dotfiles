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

# Print the authoritative side ("claude" or "agents") of $dir: the one whose
# skills/ is a real directory. Empty if neither is, "both" if both are.
_agent_sync_source() {
  local dir="$1"
  local c=0 a=0
  [[ -d "$dir/.claude/skills" && ! -L "$dir/.claude/skills" ]] && c=1
  [[ -d "$dir/.agents/skills" && ! -L "$dir/.agents/skills" ]] && a=1
  if (( c && a )); then echo both
  elif (( c )); then echo claude
  elif (( a )); then echo agents
  fi
}

_agent_sync_other() { [[ "$1" == "claude" ]] && echo agents || echo claude; }

# Skills dirs can live below the repo root (e.g. a tool in a subdirectory of a
# monorepo, which Claude Code also discovers). Print every directory from $PWD
# up to the repo root, inclusive, that has a real skills dir on either side.
_agent_sync_dirs() {
  local root="${1:A}" dir="${PWD:A}"
  [[ "$dir" == "$root" || "$dir" == "$root"/* ]] || dir="$root"
  while :; do
    [[ -n "$(_agent_sync_source "$dir")" ]] && echo "$dir"
    [[ "$dir" == "$root" || "$dir" == / ]] && break
    dir="${dir:h}"
  done
}

# Label for messages: the dir relative to the repo root ("" at the root).
_agent_sync_rel() {
  local root="${1:A}" dir="${2:A}"
  [[ "$dir" == "$root" ]] && echo "" || echo "${dir#$root/}/"
}

# Ensure $dir/.$dst/skills is a symlink to ../.$src/skills. Refuses to replace a
# real directory — migration from a copy goes through _agent_sync_migrate.
_agent_sync_link() {
  local root="$1" dir="$2" src="$3"
  local dst=$(_agent_sync_other "$src")
  local link="$dir/.$dst/skills" target="../.$src/skills"
  local rel=$(_agent_sync_rel "$root" "$dir")

  [[ -L "$link" && "$(readlink "$link")" == "$target" ]] && return 0
  if [[ -e "$link" && ! -L "$link" ]]; then
    echo "⚠ agent-sync: ${rel}.$dst/skills is a real directory; run 'agent-sync-init'"
    return 1
  fi

  mkdir -p "$dir/.$dst"
  ln -sfn "$target" "$link"
  _agent_sync_add_exclude "$root" "/${rel}.$dst/skills"
  echo "✓ agent-sync: linked ${rel}.$dst/skills → .$src/skills"
}

# Replace the old rsync mirror of .$src with a symlink. Only deletes the mirror
# when it is byte-identical to the source, so no edit is ever discarded.
_agent_sync_migrate() {
  local root="$1" dir="$2" src="$3"
  local dst=$(_agent_sync_other "$src")
  local rel=$(_agent_sync_rel "$root" "$dir")

  if ! diff -rq "$dir/.$src/skills" "$dir/.$dst/skills" >/dev/null 2>&1; then
    echo "⚠ agent-sync: ${rel}.$src/skills and ${rel}.$dst/skills differ; reconcile them, then"
    echo "  rm -rf ${rel}.$dst/skills && agent-sync-init"
    diff -rq "$dir/.$src/skills" "$dir/.$dst/skills" 2>&1 | sed 's/^/    /' | head -10
    return 1
  fi

  # A whole-directory mirror (.agents made by the old `cp -r`/rsync) holds stale
  # copies of settings, hooks etc. that only confuse other harnesses: drop it
  # entirely. Otherwise only replace skills/ and leave the rest alone. worktrees/
  # is ignored: the rsync version never copied nested worktrees across.
  if [[ "$dst" == "agents" ]] && \
     diff -rq -x worktrees "$dir/.claude" "$dir/.agents" >/dev/null 2>&1; then
    rm -rf "$dir/.agents"
  else
    rm -rf "$dir/.$dst/skills"
  fi
  _agent_sync_link "$root" "$dir" "$src" || return 1
  echo "✓ agent-sync: migrated ${rel}.$dst copy → symlink"
}

_auto_agent_sync() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ -z "$root" ]] && return 0
  _agent_sync_is_worktree "$root" && return 0

  local dir src rel
  for dir in ${(f)"$(_agent_sync_dirs "$root")"}; do
    src=$(_agent_sync_source "$dir")
    rel=$(_agent_sync_rel "$root" "$dir")
    case "$src" in
      claude|agents) _agent_sync_link "$root" "$dir" "$src" ;;
      both)
        # Old copy-based setup (repo root only): migrate automatically when the
        # legacy state file says which side is authoritative, else ask the user.
        local legacy=""
        [[ -z "$rel" ]] && legacy=$(cat "$AGENT_SYNC_DIR/$(basename "$root")" 2>/dev/null)
        if [[ "$legacy" == "claude" || "$legacy" == "agents" ]]; then
          _agent_sync_migrate "$root" "$dir" "$legacy"
        else
          echo "⚠ agent-sync: both ${rel}.claude/skills and ${rel}.agents/skills are real directories"
          echo "  Run 'agent-sync-init' there to pick the authoritative one"
        fi
        ;;
    esac
  done
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

  # Acts on the nearest skills dir at or above $PWD.
  local dir=$(_agent_sync_dirs "$root" | head -1)
  if [[ -z "$dir" ]]; then
    echo "Error: Neither .claude/skills nor .agents/skills found between here and the repo root"
    return 1
  fi

  local src=$(_agent_sync_source "$dir")
  local rel=$(_agent_sync_rel "$root" "$dir")
  case "$src" in
    claude|agents)
      _agent_sync_link "$root" "$dir" "$src"
      ;;
    both)
      echo "Both ${rel}.claude/skills and ${rel}.agents/skills are real directories. Which is authoritative?"
      select src in "claude" "agents"; do
        [[ -n "$src" ]] && { _agent_sync_migrate "$root" "$dir" "$src"; return; }
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

  local dirs=$(_agent_sync_dirs "$root")
  if [[ -z "$dirs" ]]; then
    echo "$name: no skills directory"
    return 0
  fi

  local dir src dst rel ret=0
  for dir in ${(f)dirs}; do
    src=$(_agent_sync_source "$dir")
    rel=$(_agent_sync_rel "$root" "$dir")
    case "$src" in
      both) echo "${name}${rel:+/${rel%/}}: ⚠ two real skills directories — run 'agent-sync-init'"; ret=1 ;;
      *)
        dst=$(_agent_sync_other "$src")
        if [[ -L "$dir/.$dst/skills" ]]; then
          echo "${name}${rel:+/${rel%/}}: .$dst/skills → $(readlink "$dir/.$dst/skills") (authoritative = .$src)"
        else
          echo "${name}${rel:+/${rel%/}}: authoritative = .$src, ⚠ .$dst/skills link missing — re-enter dir or run 'agent-sync-init'"
        fi
        ;;
    esac
  done
  return $ret
}
