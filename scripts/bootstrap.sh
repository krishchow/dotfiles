#!/usr/bin/env bash
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/projects/shell}"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source \"$DOTFILES/.zshrc\""
DRY_RUN="${DRY_RUN:-0}"

# ────────────────────────────── logging ──────────────────────────────

info()   { echo "→ $*"; }
ok()     { echo "✓ $*"; }
warn()   { echo "⚠ $*" >&2; }
err()    { echo "✗ $*" >&2; }
dry()    { echo "  [DRY-RUN] would: $*"; }

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        dry "$*"
        return 0
    fi
    "$@"
}

# ────────────────────────────── zshrc bootstrap ──────────────────────────────

bootstrap_zshrc() {
    info "Bootstrapping ~/.zshrc..."

    if grep -Fq "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
        ok "Source line already present in ~/.zshrc"
        return 0
    fi

    if [[ -f "$ZSHRC" ]] && [[ -s "$ZSHRC" ]]; then
        run cp "$ZSHRC" "$HOME/.zshrc.bak.$(date +%s)"
        ok "Backed up existing ~/.zshrc"
    fi

    run bash -c "echo '$SOURCE_LINE' >> \"$ZSHRC\""
    ok "Added source line to ~/.zshrc"
}

unlink_zshrc() {
    info "Removing source line from ~/.zshrc..."

    if [[ ! -f "$ZSHRC" ]]; then
        ok "~/.zshrc does not exist"
        return 0
    fi

    if ! grep -Fq "$SOURCE_LINE" "$ZSHRC"; then
        ok "Source line not found in ~/.zshrc"
        return 0
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        dry "grep -Fv '$SOURCE_LINE' $ZSHRC > $ZSHRC.tmp && mv $ZSHRC.tmp $ZSHRC"
        return 0
    fi

    grep -Fv "$SOURCE_LINE" "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
    ok "Removed source line from ~/.zshrc"
}

# ────────────────────────────── installers ──────────────────────────────

run_installers() {
    local glob="${1:-*.sh}"
    local dir="$DOTFILES/scripts/installers"
    if [[ ! -d "$dir" ]]; then
        return 0
    fi

    local count=0
    for installer in "$dir/"$glob; do
        [[ -f "$installer" ]] || continue
        unset DESCRIPTION check install 2>/dev/null || true
        source "$installer"
        if declare -f check &>/dev/null && check; then
            ok "${DESCRIPTION:-$(basename "$installer")} already installed"
        elif declare -f install &>/dev/null; then
            info "Installing ${DESCRIPTION:-$(basename "$installer")}..."
            run install
            ok "${DESCRIPTION:-$(basename "$installer")} installed"
            count=$((count + 1))
        else
            warn "Installer $installer has no install() function, skipping"
        fi
    done
    if (( count > 0 )); then
        ok "Installed $count new component(s)"
    fi
}

# ────────────────────────────── repo-sync launchd agent ──────────────────────────────

install_sync() {
    local template="$DOTFILES/repo-sync/repo-sync.plist.template"
    local plist_dst="$HOME/Library/LaunchAgents/com.repo-sync.plist"
    local log_dir="$HOME/logs"

    info "Installing repo-sync launchd agent..."

    if [[ ! -d "$log_dir" ]]; then
        run mkdir -p "$log_dir"
    fi

    if [[ -f "$plist_dst" ]] || [[ -L "$plist_dst" ]]; then
        if launchctl list 2>/dev/null | grep -q "com.repo-sync"; then
            info "Unloading existing agent..."
            run launchctl unload "$plist_dst"
        fi
        run rm -f "$plist_dst"
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        dry "sed 's|__HOME__|$HOME|g; s|__DOTFILES__|$DOTFILES|g' $template > $plist_dst"
        dry "launchctl load $plist_dst"
    else
        sed "s|__HOME__|$HOME|g; s|__DOTFILES__|$DOTFILES|g" "$template" > "$plist_dst"
        launchctl load "$plist_dst"
    fi
    ok "Repo-sync agent installed and loaded (runs every hour)"
}

uninstall_sync() {
    local plist_dst="$HOME/Library/LaunchAgents/com.repo-sync.plist"

    info "Uninstalling repo-sync launchd agent..."

    if [[ -f "$plist_dst" ]] || [[ -L "$plist_dst" ]]; then
        if launchctl list 2>/dev/null | grep -q "com.repo-sync"; then
            run launchctl unload "$plist_dst"
        fi
        run rm -f "$plist_dst"
        ok "Repo-sync agent uninstalled"
    else
        ok "Repo-sync agent not installed"
    fi
}

# ────────────────────────────── dispatch ──────────────────────────────

usage() {
    echo "Usage: $0 {link|brew|unlink|install|sync-install|sync-uninstall}"
    echo ""
    echo "  link           Bootstrap ~/.zshrc source line"
    echo "  brew           Install Homebrew + Brewfile packages"
    echo "  unlink         Remove source line from ~/.zshrc"
    echo "  install        Full setup: link + all installers"
    echo "  sync-install   Install repo-sync launchd agent"
    echo "  sync-uninstall Uninstall repo-sync launchd agent"
    echo ""
    echo "Environment:"
    echo "  DRY_RUN=1  Preview without making changes"
    exit 1
}

case "${1:-}" in
    link)
        bootstrap_zshrc
        ;;
    brew)
        run_installers "0[01]-*"
        ;;
    unlink)
        unlink_zshrc
        ;;
    install)
        bootstrap_zshrc
        run_installers
        ;;
    sync-install)
        install_sync
        ;;
    sync-uninstall)
        uninstall_sync
        ;;
    *)
        usage
        ;;
esac
