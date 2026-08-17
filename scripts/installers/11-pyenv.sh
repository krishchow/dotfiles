DESCRIPTION="pyenv global Python version"

check() {
    [[ -f "$DOTFILES/.python-version" ]] || return 0
    command -v pyenv &>/dev/null || return 1
    [[ "$(pyenv global)" == "$(cat "$DOTFILES/.python-version")" ]]
}

install() {
    local version
    version="$(cat "$DOTFILES/.python-version")"
    pyenv install --skip-existing "$version"
    pyenv global "$version"
}
