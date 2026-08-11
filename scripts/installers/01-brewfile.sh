DESCRIPTION="Brewfile packages"
check() { brew bundle check --file="$DOTFILES/Brewfile" &>/dev/null; }
install() { brew bundle install --file="$DOTFILES/Brewfile" --no-upgrade; }
