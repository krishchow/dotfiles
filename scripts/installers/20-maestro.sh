DESCRIPTION="Maestro"
check() { command -v maestro &>/dev/null; }
install() { curl -fsSL "https://get.maestro.mobile.dev" | bash; }
