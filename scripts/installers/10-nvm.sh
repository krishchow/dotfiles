DESCRIPTION="nvm (Node Version Manager)"

check() {
    [[ -s "$HOME/.nvm/nvm.sh" ]] || return 1
    if [[ -f "$DOTFILES/.nvmrc" ]]; then
        set +u; \. "$HOME/.nvm/nvm.sh" 2>/dev/null; set -u
        [[ "$(nvm version default 2>/dev/null)" == "$(cat "$DOTFILES/.nvmrc")" ]]
    fi
}

install() {
    if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    if [[ -f "$DOTFILES/.nvmrc" ]]; then
        set +u; \. "$HOME/.nvm/nvm.sh"; set -u
        nvm install --default "$(cat "$DOTFILES/.nvmrc")"
    fi
}
