DESCRIPTION="Homebrew"
check() { command -v brew &>/dev/null; }
install() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  local brew_prefix
  if [[ "$(uname -m)" == "arm64" ]]; then
    brew_prefix="/opt/homebrew"
  else
    brew_prefix="/usr/local"
  fi
  eval "$($brew_prefix/bin/brew shellenv)"
}
