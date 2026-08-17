DESCRIPTION="dotfiles git config include"

check() {
    [[ -f "$DOTFILES/git/gitconfig" ]] || return 0
    git config --global --get-all include.path 2>/dev/null | grep -qF "$DOTFILES/git/gitconfig"
}

install() { git config --global --add include.path "$DOTFILES/git/gitconfig"; }
