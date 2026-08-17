#!/usr/bin/env bash
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/projects/shell}"
DRY_RUN="${DRY_RUN:-0}"
DATE_TAG="$(date +%Y-%m-%d)"

info() { echo "→ $*"; }
ok()   { echo "✓ $*"; }
dry()  { echo "  [DRY-RUN] would: $*"; }

RC_FILES=("$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.bash_profile" "$HOME/.bashrc")
PATH_TOKEN_RE='[A-Za-z0-9_/.{}$-]*/[A-Za-z0-9_/.{}$-]*'

NEW_PATH_HEADER_WRITTEN=0
NEW_ALIAS_HEADER_WRITTEN=0

REPORT_NEW=""
REPORT_ENV=""
REPORT_OTHER=""
REPORT_DUP=""

# Extracts path-like tokens (segments containing "/") from a line and checks
# whether every one already appears in .path — literally, or with the live
# $HOME value normalized back to the "$HOME" variable form (rc files tend to
# have $HOME expanded to a literal path; .path tends to use the variable).
is_duplicate_path() {
    local line="$1" token normalized found_any=0
    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        found_any=1
        normalized="${token//$HOME/\$HOME}"
        if grep -qF "$token" "$DOTFILES/.path" 2>/dev/null; then
            continue
        elif [[ "$normalized" != "$token" ]] && grep -qF "$normalized" "$DOTFILES/.path" 2>/dev/null; then
            continue
        else
            return 1
        fi
    done < <(grep -oE "$PATH_TOKEN_RE" <<< "$line" || true)
    [[ "$found_any" == "1" ]]
}

migrate_path_line() {
    local line="$1" comment="$2" src="$3"
    if [[ "$DRY_RUN" == "1" ]]; then
        dry "append PATH line to .path: $line (from $src)"
        return
    fi
    if [[ "$NEW_PATH_HEADER_WRITTEN" == "0" ]]; then
        { echo ""; echo "# --- deepfreeze: migrated from $src on $DATE_TAG ---"; } >> "$DOTFILES/.path"
        NEW_PATH_HEADER_WRITTEN=1
    fi
    [[ -n "$comment" ]] && printf '%s\n' "$comment" >> "$DOTFILES/.path"
    echo "$line" >> "$DOTFILES/.path"
}

migrate_alias_line() {
    local line="$1" comment="$2" src="$3"
    if [[ "$DRY_RUN" == "1" ]]; then
        dry "append alias line to .aliases: $line (from $src)"
        return
    fi
    if [[ "$NEW_ALIAS_HEADER_WRITTEN" == "0" ]]; then
        { echo ""; echo "# --- deepfreeze: migrated from $src on $DATE_TAG ---"; } >> "$DOTFILES/.aliases"
        NEW_ALIAS_HEADER_WRITTEN=1
    fi
    [[ -n "$comment" ]] && printf '%s\n' "$comment" >> "$DOTFILES/.aliases"
    echo "$line" >> "$DOTFILES/.aliases"
}

info "Scanning shell rc files for un-migrated additions..."

for rc in "${RC_FILES[@]}"; do
    [[ -f "$rc" ]] || continue

    prev_comment=""
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line="$(printf '%s' "$raw_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        if [[ -z "$line" ]]; then
            prev_comment=""
            continue
        fi
        if [[ "$line" == \#* ]]; then
            prev_comment="${prev_comment:+$prev_comment$'\n'}$line"
            continue
        fi
        if [[ "$line" == *"$DOTFILES"* ]]; then
            prev_comment=""
            continue
        fi

        if [[ "$line" =~ ^alias\ [A-Za-z0-9_-]+= ]]; then
            name="$(printf '%s' "$line" | sed -E 's/^alias ([A-Za-z0-9_-]+)=.*/\1/')"
            if grep -qE "^alias ${name}=" "$DOTFILES/.aliases" 2>/dev/null; then
                REPORT_DUP="${REPORT_DUP}  $line  ($rc)
"
            else
                migrate_alias_line "$line" "$prev_comment" "$rc"
                REPORT_NEW="${REPORT_NEW}  $line  ($rc -> .aliases)
"
            fi
        elif [[ "$line" == *"PATH="* ]]; then
            if is_duplicate_path "$line"; then
                REPORT_DUP="${REPORT_DUP}  $line  ($rc)
"
            else
                migrate_path_line "$line" "$prev_comment" "$rc"
                REPORT_NEW="${REPORT_NEW}  $line  ($rc -> .path)
"
            fi
        elif [[ "$line" =~ ^export\ [A-Z_][A-Z0-9_]*= ]]; then
            REPORT_ENV="${REPORT_ENV}  $line  ($rc)
"
        else
            REPORT_OTHER="${REPORT_OTHER}  $line  ($rc)
"
        fi

        prev_comment=""
    done < "$rc"
done

echo ""
if [[ -n "$REPORT_NEW" ]]; then
    echo "New additions migrated into .path / .aliases:"
    printf '%s' "$REPORT_NEW"
else
    echo "No new PATH/alias additions found."
fi

if [[ -n "$REPORT_ENV" ]]; then
    echo ""
    echo "Env var exports found — NOT auto-migrated (.env is protected; add manually if needed):"
    printf '%s' "$REPORT_ENV"
fi

if [[ -n "$REPORT_OTHER" ]]; then
    echo ""
    echo "Other lines needing manual review (eval/source/multi-line constructs, not auto-migrated):"
    printf '%s' "$REPORT_OTHER"
fi

if [[ -n "$REPORT_DUP" ]]; then
    echo ""
    echo "Already covered by dotfiles — safe to remove manually from the source files:"
    printf '%s' "$REPORT_DUP"
fi

echo ""
ok "Shell-rc scan complete"
