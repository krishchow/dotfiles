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

# ────────────────────────────── brewfile freeze ──────────────────────────────

freeze_brewfile() {
    local brewfile="$DOTFILES/Brewfile"
    local ignore_file="$DOTFILES/.brewignore"
    local tmpfile
    tmpfile="$(mktemp)"

    info "Freezing installed packages to Brewfile..."

    if [[ "$DRY_RUN" == "1" ]]; then
        dry "brew bundle dump --force --no-describe --no-mas --no-vscode --file=$brewfile (respecting .brewignore)"
        rm -f "$tmpfile"
        return 0
    fi

    brew bundle dump --force --no-describe --no-mas --no-vscode --file="$tmpfile"

    if [[ -f "$ignore_file" ]]; then
        local pattern_file
        pattern_file="$(mktemp)"
        grep -Ev '^[[:space:]]*(#|$)' "$ignore_file" | sed 's/^/"/; s/$/"/' > "$pattern_file"
        grep -vFf "$pattern_file" "$tmpfile" > "$tmpfile.filtered" || true
        mv "$tmpfile.filtered" "$tmpfile"
        rm -f "$pattern_file"
        ok "Applied exclusions from .brewignore"
    fi

    mv "$tmpfile" "$brewfile"
    ok "Brewfile updated with current package state"
}

# ────────────────────────────── runtime version freeze ──────────────────────────────

freeze_runtime_versions() {
    info "Freezing runtime version pins..."

    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        set +u
        \. "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        set -u
        local node_version
        node_version="$(nvm version default 2>/dev/null || true)"
        if [[ -n "$node_version" && "$node_version" != "N/A" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                dry "write $node_version to $DOTFILES/.nvmrc"
            else
                echo "$node_version" > "$DOTFILES/.nvmrc"
                ok "Pinned nvm default version: $node_version"
            fi
        else
            info "No nvm default alias set — skipping .nvmrc"
        fi
    fi

    if command -v pyenv &>/dev/null; then
        local py_version
        py_version="$(pyenv global 2>/dev/null || true)"
        if [[ -n "$py_version" && "$py_version" != "system" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                dry "write $py_version to $DOTFILES/.python-version"
            else
                echo "$py_version" > "$DOTFILES/.python-version"
                ok "Pinned pyenv global version: $py_version"
            fi
        else
            info "pyenv global is 'system' or unset — nothing to pin"
        fi
    fi
}

# ────────────────────────────── git config freeze ──────────────────────────────

freeze_git_config() {
    local extra="$DOTFILES/git/gitconfig"

    info "Freezing global git config extras..."

    if [[ "$DRY_RUN" == "1" ]]; then
        dry "capture git config --global --list (excluding user.*/github.user/filter.lfs.*/credential-shaped keys) into $extra"
        return 0
    fi

    mkdir -p "$(dirname "$extra")"
    touch "$extra"

    local added=0 skipped=0
    local key
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        case "$key" in
            user.*|github.user|filter.lfs.*|credential.*|url.*.insteadof) continue ;;
        esac
        if [[ "$key" =~ (token|secret|credential|password) ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        local -a values=()
        local value has_secret=0
        while IFS= read -r value; do
            [[ -z "$value" ]] && continue
            if [[ "$value" =~ (token|secret|password) ]]; then
                skipped=$((skipped + 1))
                has_secret=1
                continue
            fi
            values+=("$value")
        done < <(git config --global --get-all "$key" 2>/dev/null || true)

        # Re-sync this key's values so stale/replaced entries (e.g. core.editor
        # changing vim -> nvim) don't linger as duplicate lines.
        (( has_secret )) && continue
        local existing
        existing="$(git config --file "$extra" --get-all "$key" 2>/dev/null || true)"
        local desired
        desired="$(printf '%s\n' "${values[@]}")"
        if [[ "$existing" != "$desired" ]]; then
            git config --file "$extra" --unset-all "$key" 2>/dev/null || true
            for value in "${values[@]}"; do
                git config --file "$extra" --add "$key" "$value"
            done
            added=$((added + 1))
        fi
    done < <(git config --global --name-only --list 2>/dev/null | sort -u)

    if (( added > 0 )); then
        ok "Added $added new git config entr$([[ $added -eq 1 ]] && echo y || echo ies) to git/gitconfig"
    else
        ok "git/gitconfig already up to date"
    fi
    if (( skipped > 0 )); then
        warn "Skipped $skipped credential/token/secret-shaped git config entr$([[ $skipped -eq 1 ]] && echo y || echo ies) — review manually if needed"
    fi
}

# ────────────────────────────── custom launchd agents ──────────────────────────────

LAUNCHD_VENDOR_PREFIXES=(com.apple. com.google. com.microsoft. com.docker. com.adobe. com.oracle. com.jetbrains. org.mozilla. com.1password.)

freeze_launchd_agents() {
    local src_dir="$HOME/Library/LaunchAgents"
    local dst_dir="$DOTFILES/launchd"

    info "Freezing custom launchd agents..."

    if [[ ! -d "$src_dir" ]]; then
        ok "No LaunchAgents directory found"
        return 0
    fi

    local found=0
    local plist
    for plist in "$src_dir/"*.plist; do
        [[ -f "$plist" ]] || continue
        local label
        label="$(basename "$plist" .plist)"

        local prefix skip=0
        for prefix in "${LAUNCHD_VENDOR_PREFIXES[@]}"; do
            if [[ "$label" == "$prefix"* ]]; then
                skip=1
                break
            fi
        done
        (( skip )) && continue

        grep -qF "$DOTFILES" "$plist" 2>/dev/null && continue

        found=$((found + 1))
        local dst="$dst_dir/${label}.plist.template"
        if [[ "$DRY_RUN" == "1" ]]; then
            dry "capture $plist -> $dst (templated)"
            continue
        fi
        mkdir -p "$dst_dir"
        sed "s|$HOME|__HOME__|g" "$plist" > "$dst"
        ok "Captured $label -> launchd/${label}.plist.template"
    done

    if (( found == 0 )); then
        ok "No new custom launchd agents found"
    fi
}

install_launchd_agents() {
    local dir="$DOTFILES/launchd"

    info "Installing custom launchd agents..."

    if [[ ! -d "$dir" ]]; then
        ok "No custom launchd agents to install"
        return 0
    fi

    local log_dir="$HOME/logs"
    [[ -d "$log_dir" ]] || run mkdir -p "$log_dir"

    local template found=0
    for template in "$dir/"*.plist.template; do
        [[ -f "$template" ]] || continue
        found=1
        local label
        label="$(basename "$template" .plist.template)"
        local plist_dst="$HOME/Library/LaunchAgents/${label}.plist"

        info "Installing $label launchd agent..."
        if [[ -f "$plist_dst" ]] || [[ -L "$plist_dst" ]]; then
            if launchctl list 2>/dev/null | grep -q "$label"; then
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
        ok "$label agent installed and loaded"
    done

    (( found )) || ok "No custom launchd agents to install"
}

uninstall_launchd_agents() {
    local dir="$DOTFILES/launchd"

    info "Uninstalling custom launchd agents..."

    if [[ ! -d "$dir" ]]; then
        ok "No custom launchd agents installed"
        return 0
    fi

    local template found=0
    for template in "$dir/"*.plist.template; do
        [[ -f "$template" ]] || continue
        found=1
        local label
        label="$(basename "$template" .plist.template)"
        local plist_dst="$HOME/Library/LaunchAgents/${label}.plist"

        if [[ -f "$plist_dst" ]] || [[ -L "$plist_dst" ]]; then
            if launchctl list 2>/dev/null | grep -q "$label"; then
                run launchctl unload "$plist_dst"
            fi
            run rm -f "$plist_dst"
            ok "$label agent uninstalled"
        fi
    done

    (( found )) || ok "No custom launchd agents to uninstall"
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
    echo "Usage: $0 {link|brew|unlink|install|freeze|deepfreeze|sync-install|sync-uninstall|launchd-install|launchd-uninstall}"
    echo ""
    echo "  link                Bootstrap ~/.zshrc source line"
    echo "  brew                Install Homebrew + Brewfile packages"
    echo "  unlink              Remove source line from ~/.zshrc"
    echo "  install             Full setup: link + all installers"
    echo "  freeze              Snapshot installed brew packages into Brewfile"
    echo "  deepfreeze          freeze + runtime versions + git config + shell-rc + launchd agents"
    echo "  sync-install        Install repo-sync launchd agent"
    echo "  sync-uninstall      Uninstall repo-sync launchd agent"
    echo "  launchd-install     Install custom launchd agents captured under launchd/"
    echo "  launchd-uninstall   Uninstall custom launchd agents captured under launchd/"
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
    freeze)
        freeze_brewfile
        ;;
    deepfreeze)
        freeze_brewfile
        freeze_runtime_versions
        freeze_git_config
        freeze_launchd_agents
        "$DOTFILES/scripts/deepfreeze-shell.sh"
        ;;
    sync-install)
        install_sync
        ;;
    sync-uninstall)
        uninstall_sync
        ;;
    launchd-install)
        install_launchd_agents
        ;;
    launchd-uninstall)
        uninstall_launchd_agents
        ;;
    *)
        usage
        ;;
esac
