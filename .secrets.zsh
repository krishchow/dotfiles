if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="$HOME/projects/shell"
fi

# secrets/ is a private submodule, absent or
# empty on machines without access. secrets/.env holds plain KEY=VALUE pairs;
# generate-secrets-env.sh turns it into secrets/secrets.sh (gitignored,
# properly quoted `export` lines) which we source here.
if [[ -f "$DOTFILES/secrets/.env" ]]; then
    "$DOTFILES/scripts/generate-secrets-env.sh"
    if [[ -f "$DOTFILES/secrets/secrets.sh" ]]; then
        source "$DOTFILES/secrets/secrets.sh"
    fi
fi
