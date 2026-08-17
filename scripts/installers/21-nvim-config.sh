DESCRIPTION="neovim config (symlink tracked init.vim)"

check() {
    [[ -L "$HOME/.config/nvim/init.vim" ]] || return 1
    [[ "$(readlink "$HOME/.config/nvim/init.vim")" == "$DOTFILES/nvim/init.vim" ]]
}

install() {
    mkdir -p "$HOME/.config/nvim"
    ln -sf "$DOTFILES/nvim/init.vim" "$HOME/.config/nvim/init.vim"
}
