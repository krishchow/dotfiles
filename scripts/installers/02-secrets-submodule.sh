DESCRIPTION="secrets/ submodule (private secrets repo)"

check() {
    [[ -e "$DOTFILES/secrets/.git" ]]
}

install() {
    if ! git -C "$DOTFILES" submodule update --init secrets; then
        warn "Could not init secrets/ submodule (no access to the private repo from this machine?) — skipping"
    fi
}
