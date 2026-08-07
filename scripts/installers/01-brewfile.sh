DESCRIPTION="Brewfile packages"
check() { command -v brew &>/dev/null; }
install() { brew bundle --file="$DOTFILES/Brewfile" --no-lock; }
