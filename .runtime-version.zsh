if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi

autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_runtime_version

_find_up() {
  local file=$1 dir=$PWD
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/$file" ]]; then
      echo "$dir/$file"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

_auto_runtime_version() {
  if typeset -f nvm >/dev/null 2>&1; then
    local nvmrc=$(_find_up .nvmrc)
    if [[ -n "$nvmrc" ]]; then
      nvm use --silent
    elif [[ -n "${_LAST_NVM_VERSION:-}" ]]; then
      nvm use default --silent
    fi
    local current=$(nvm current 2>/dev/null)
    if [[ "$current" != "${_LAST_NVM_VERSION:-}" ]]; then
      echo "✓ Now using node $current"
      _LAST_NVM_VERSION="$current"
    fi
  fi

  if command -v pyenv >/dev/null 2>&1; then
    local pyver_file=$(_find_up .python-version)
    if [[ -n "$pyver_file" ]]; then
      export PYENV_VERSION=$(pyenv version-name)
    else
      unset PYENV_VERSION
    fi
  fi
}

_auto_runtime_version
