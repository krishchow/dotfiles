if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi
export AGENT_SYNC_DIR="$DOTFILES/agent-sync"

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_agent_sync

_agent_sync_do() {
  local root="$1" src="$2" dst="$3" force="$4"
  if [[ ! -d "$root/.$src" ]]; then
    echo "✗ agent-sync: authoritative .$src missing, skipping sync"
    return 1
  fi
  [[ "$force" != "force" ]] && rsync -ain --delete --exclude='.git' "$root/.$src/" "$root/.$dst/" 2>/dev/null | grep -q '^[<>ch.*]' || { [[ "$force" == "force" ]] && true || return 0; }
  rsync -a --delete --exclude='.git' "$root/.$src/" "$root/.$dst/" 2>/dev/null
  _agent_sync_add_exclude "$root" "$dst"
  echo "✓ agent-sync: synced .$src → .$dst"
}

_agent_sync_add_exclude() {
  local root="$1" dir="$2"
  local exclude="$root/.git/info/exclude"
  grep -qF "/.$dir" "$exclude" 2>/dev/null && return 0
  echo "/.$dir" >> "$exclude"
}

_auto_agent_sync() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    return 0
  fi

  local name=$(basename "$root")
  local state_file="$AGENT_SYNC_DIR/$name"

  local has_claude_dir=0 has_agents_dir=0
  [[ -d "$root/.claude" ]] && has_claude_dir=1
  [[ -d "$root/.agents" ]] && has_agents_dir=1

  if (( ! has_claude_dir && ! has_agents_dir )); then
    return 0
  fi

  if [[ -f "$state_file" ]]; then
    local src=$(cat "$state_file")
    if [[ "$src" == "claude" ]]; then
      _agent_sync_do "$root" "claude" "agents"
    elif [[ "$src" == "agents" ]]; then
      _agent_sync_do "$root" "agents" "claude"
    fi
    return 0
  fi

  if (( has_claude_dir && ! has_agents_dir )); then
    cp -r "$root/.claude" "$root/.agents"
    echo "claude" > "$state_file"
    _agent_sync_add_exclude "$root" "agents"
    echo "✓ agent-sync: copied .claude → .agents (claude is authoritative)"
    return 0
  fi

  if (( ! has_claude_dir && has_agents_dir )); then
    cp -r "$root/.agents" "$root/.claude"
    echo "agents" > "$state_file"
    _agent_sync_add_exclude "$root" "claude"
    echo "✓ agent-sync: copied .agents → .claude (agents is authoritative)"
    return 0
  fi

  if (( has_claude_dir && has_agents_dir )); then
    echo "⚠ agent-sync: both .claude and .agents exist but no state file"
    echo "  Run 'agent-sync-init' to set which is authoritative"
    return 0
  fi
}

agent-sync-init() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local name=$(basename "$root")
  local state_file="$AGENT_SYNC_DIR/$name"

  local has_claude=0 has_agents=0
  [[ -d "$root/.claude" ]] && has_claude=1
  [[ -d "$root/.agents" ]] && has_agents=1

  if (( ! has_claude && ! has_agents )); then
    echo "Error: Neither .claude nor .agents directory found"
    return 1
  fi

  if (( has_claude && has_agents )); then
    echo "Both .claude and .agents exist. Which is authoritative?"
    select src in "claude" "agents"; do
      if [[ -n "$src" ]]; then
        echo "$src" > "$state_file"
        if [[ "$src" == "claude" ]]; then
          _agent_sync_add_exclude "$root" "agents"
        else
          _agent_sync_add_exclude "$root" "claude"
        fi
        echo "✓ Set .$src as authoritative for $name"
        return 0
      fi
    done
  fi

  if (( has_claude && ! has_agents )); then
    echo "claude" > "$state_file"
    cp -r "$root/.claude" "$root/.agents"
    _agent_sync_add_exclude "$root" "agents"
    echo "✓ agent-sync: .claude → .agents (claude is authoritative)"
    return 0
  fi

  if (( ! has_claude && has_agents )); then
    echo "agents" > "$state_file"
    cp -r "$root/.agents" "$root/.claude"
    _agent_sync_add_exclude "$root" "claude"
    echo "✓ agent-sync: .agents → .claude (agents is authoritative)"
    return 0
  fi
}

agent-sync-force() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local name=$(basename "$root")
  local state_file="$AGENT_SYNC_DIR/$name"

  if [[ ! -f "$state_file" ]]; then
    echo "Error: No sync state found for $name"
    echo "Run 'agent-sync-init' or re-enter this directory to auto-detect"
    return 1
  fi

  local src=$(cat "$state_file")
  local dst=""
  if [[ "$src" == "claude" ]]; then
    dst="agents"
  elif [[ "$src" == "agents" ]]; then
    dst="claude"
  else
    echo "Error: Unknown authoritative source: $src"
    return 1
  fi

  if [[ ! -d "$root/.$src" ]]; then
    echo "Error: Authoritative directory .$src not found"
    return 1
  fi

  rm -rf "$root/.$dst"
  cp -r "$root/.$src" "$root/.$dst"
  _agent_sync_add_exclude "$root" "$dst"
  echo "✓ agent-sync: force-synced .$src → .$dst"
}

agent-sync-status() {
  local root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "Not in a git repository"
    return 1
  fi

  local name=$(basename "$root")
  local state_file="$AGENT_SYNC_DIR/$name"

  if [[ ! -f "$state_file" ]]; then
    echo "$name: not synced (no state file)"
    return 0
  fi

  local src=$(cat "$state_file")
  echo "$name: authoritative = .$src"

  local has_src=0 has_dst=0
  local dst
  if [[ "$src" == "claude" ]]; then dst="agents"; else dst="claude"; fi
  [[ -d "$root/.$src" ]] && has_src=1
  [[ -d "$root/.$dst" ]] && has_dst=1

  (( has_src && has_dst )) && echo "  both directories present" && return 0
  (( has_src && ! has_dst )) && echo "  ⚠ .$dst is missing — re-enter dir or run agent-sync-force" && return 0
  (( !has_src && has_dst )) && echo "  ⚠ authoritative .$src is missing!" && return 1
  echo "  ⚠ neither directory found" && return 1
}
