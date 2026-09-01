DESCRIPTION="~/.npmrc (GitHub Packages @concoursetech scope)"

NPMRC_FILE="$HOME/.npmrc"
NPMRC_BEGIN="# >>> dotfiles npmrc >>>"
NPMRC_END="# <<< dotfiles npmrc <<<"

check() {
    [[ -f "$NPMRC_FILE" ]] && grep -qF "$NPMRC_BEGIN" "$NPMRC_FILE"
}

# pnpm 10 refuses to expand ${VAR} in a *project* .npmrc (that file is committed,
# so a bad registry line could leak the token) but still expands it in the
# user-level one — so the @concoursetech scope auth has to live here.
# NODE_AUTH_TOKEN comes from the secrets/ submodule via .secrets.zsh.
install() {
    [[ -f "$NPMRC_FILE" ]] || : > "$NPMRC_FILE"
    {
        echo "$NPMRC_BEGIN"
        echo "@concoursetech:registry=https://npm.pkg.github.com"
        echo '//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}'
        echo "$NPMRC_END"
    } >> "$NPMRC_FILE"
    chmod 600 "$NPMRC_FILE"
}
