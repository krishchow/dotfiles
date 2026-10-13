DESCRIPTION="Ghostty terminal definition (user-local terminfo)"

check() {
    command -v infocmp >/dev/null && infocmp -x xterm-ghostty >/dev/null 2>&1
}

install() {
    command -v tic >/dev/null || {
        echo "Ghostty terminfo requires tic (Debian: apt-get install ncurses-bin)." >&2
        return 1
    }
    command -v infocmp >/dev/null || {
        echo "Ghostty terminfo requires infocmp (Debian: apt-get install ncurses-bin)." >&2
        return 1
    }
    mkdir -p "$HOME/.terminfo"
    tic -x -o "$HOME/.terminfo" "$DOTFILES/terminfo/xterm-ghostty.terminfo"
    TERMINFO="$HOME/.terminfo" infocmp -x xterm-ghostty >/dev/null
}
