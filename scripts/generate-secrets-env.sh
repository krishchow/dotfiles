#!/usr/bin/env bash
# Regenerates secrets/secrets.sh (gitignored, POSIX `export KEY='value'` lines)
# from secrets/.env (plain KEY=VALUE, hand-maintained in the private submodule).
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_ENV="$DOTFILES/secrets/.env"
SECRETS_OUT="$DOTFILES/secrets/secrets.sh"

[[ -f "$SECRETS_ENV" ]] || exit 0

{
    echo "# generated from secrets/.env by scripts/generate-secrets-env.sh -- do not edit"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"

        # strip one layer of surrounding quotes, if present
        if [[ ${#value} -ge 2 ]]; then
            first="${value:0:1}"
            last="${value: -1}"
            if [[ ("$first" == '"' && "$last" == '"') || ("$first" == "'" && "$last" == "'") ]]; then
                value="${value#?}"
                value="${value%?}"
            fi
        fi

        printf -v quoted '%q' "$value"
        printf 'export %s=%s\n' "$key" "$quoted"
    done < "$SECRETS_ENV"
} > "$SECRETS_OUT"
