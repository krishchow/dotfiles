DESCRIPTION="nvm (Node Version Manager)"
check() { [[ -s "$HOME/.nvm/nvm.sh" ]]; }
install() { curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; }
