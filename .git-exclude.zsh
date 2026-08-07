if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi
export GIT_EXCLUDE_DIR="$DOTFILES/ignore"

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_link_git_exclude

_auto_link_git_exclude() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    return 0
  fi

  local repo_name=$(basename "$repo_root")
  local exclude_file="$GIT_EXCLUDE_DIR/$repo_name"
  local target="$repo_root/.git/info/exclude"

  if [[ ! -f "$exclude_file" && -f "$target" && ! -L "$target" ]]; then
    if grep -qv '^[[:space:]]*\(#\|$\)' "$target" 2>/dev/null; then
      echo "✓ Backfilling custom exclude file for $repo_name"
      cp "$target" "$exclude_file"
    fi
  fi

  if [[ ! -f "$exclude_file" ]]; then
    return 0
  fi

  if [[ -L "$target" ]]; then
    local current_target=$(readlink "$target")
    if [[ "$current_target" == "$exclude_file" ]]; then
      return 0
    fi
  fi

  if [[ -f "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.backup"
  elif [[ -L "$target" ]]; then
    rm "$target"
  fi

  ln -sf "$exclude_file" "$target"
  echo "✓ Auto-linked git exclude for $repo_name"
}

link-git-exclude() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local repo_name=$(basename "$repo_root")
  local exclude_file="$GIT_EXCLUDE_DIR/$repo_name"
  local target="$repo_root/.git/info/exclude"

  if [[ ! -f "$exclude_file" ]]; then
    echo "Error: No exclude file found at $exclude_file"
    echo "Run 'init-git-exclude' to create one"
    return 1
  fi

  if [[ -f "$target" && ! -L "$target" ]]; then
    echo "Backing up existing exclude file to $target.backup"
    mv "$target" "$target.backup"
  elif [[ -L "$target" ]]; then
    rm "$target"
  fi

  ln -sf "$exclude_file" "$target"
  echo "✓ Linked $repo_name exclude file"
  echo "  $target -> $exclude_file"
}

edit-git-exclude() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local repo_name=$(basename "$repo_root")
  local exclude_file="$GIT_EXCLUDE_DIR/$repo_name"

  if [[ ! -f "$exclude_file" ]]; then
    echo "Error: No exclude file found at $exclude_file"
    echo "Run 'init-git-exclude' to create one"
    return 1
  fi

  ${EDITOR:-vim} "$exclude_file"
}

init-git-exclude() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local repo_name=$(basename "$repo_root")
  local exclude_file="$GIT_EXCLUDE_DIR/$repo_name"
  local target="$repo_root/.git/info/exclude"

  if [[ -f "$exclude_file" ]]; then
    echo "Exclude file already exists: $exclude_file"
    read "response?Overwrite? (y/N) "
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      return 0
    fi
  fi

  if [[ -f "$target" && ! -L "$target" ]]; then
    echo "Copying existing exclude file to $exclude_file"
    cp "$target" "$exclude_file"
  else
    cat > "$exclude_file" <<'EOF'
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.

EOF
  fi

  echo "✓ Created exclude file: $exclude_file"
  echo "Run 'link-git-exclude' to activate (or cd into repo to auto-link)"
}

_auto_link_git_exclude
