DESCRIPTION="ssh config include (from private secrets/ submodule)"

SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_INCLUDE_BEGIN="# >>> dotfiles ssh >>>"
SSH_INCLUDE_END="# <<< dotfiles ssh <<<"

check() {
    [[ -f "$SSH_CONFIG_FILE" ]] && grep -qF "$SSH_INCLUDE_BEGIN" "$SSH_CONFIG_FILE"
}

# Host blocks live in the private secrets/ submodule (secrets/ssh/config); this
# public repo only wires them in. Include must come before any Host/Match block,
# or it's scoped to that block — so this prepends rather than appends. ssh
# silently ignores a missing Include path, so it's a no-op without the submodule.
install() {
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    [[ -f "$SSH_CONFIG_FILE" ]] || : > "$SSH_CONFIG_FILE"
    {
        echo "$SSH_INCLUDE_BEGIN"
        echo "Include $DOTFILES/secrets/ssh/config"
        echo "$SSH_INCLUDE_END"
        echo
        cat "$SSH_CONFIG_FILE"
    } > "$SSH_CONFIG_FILE.tmp" && mv "$SSH_CONFIG_FILE.tmp" "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"
}
