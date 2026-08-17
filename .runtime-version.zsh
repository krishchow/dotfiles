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
  local announce=${1:-1}
  if typeset -f nvm >/dev/null 2>&1; then
    local nvmrc=$(_find_up .nvmrc)
    if [[ -n "$nvmrc" ]]; then
      nvm use --silent
    fi
    local current=$(nvm current 2>/dev/null)
    if [[ "$announce" == "1" && "$current" != "${_LAST_NVM_VERSION:-}" && "${_LAST_NVM_VERSION:-}" != "system"  ]]; then
      echo "✓ Now using node $current"
    fi
    _LAST_NVM_VERSION="$current"
  fi

  if command -v pyenv >/dev/null 2>&1; then
    local pyver_file=$(_find_up .python-version)
    if [[ -n "$pyver_file" ]]; then
      export PYENV_VERSION=$(pyenv version-name)
    fi
  fi
}

_auto_runtime_version 0
