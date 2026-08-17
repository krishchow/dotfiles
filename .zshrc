# Auto-detect the directory this file lives in (works wherever the repo is cloned).
# $0 = path to this sourced file, :A = resolve to absolute, :h = dirname
DOTFILES="${0:A:h}"

source "$DOTFILES/.env"
source "$DOTFILES/.path"
source "$DOTFILES/.aliases"
source "$DOTFILES/.history.zsh"
source "$DOTFILES/.git-exclude.zsh"
source "$DOTFILES/.agent-sync.zsh"
# source "$DOTFILES/.runtime-version.zsh"
source "$DOTFILES/.secrets.zsh"
