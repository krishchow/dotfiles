#!/bin/bash
set -euo pipefail

die() { echo "✗ $*" >&2; exit 1; }
info() { echo "→ $*"; }
ok() { echo "✓ $*"; }

if ! command -v gh &>/dev/null; then
  die "gh CLI not found. Install: brew install gh && gh auth login"
fi
if ! gh auth status &>/dev/null; then
  die "gh not authenticated. Run: gh auth login"
fi

# --- detect scope ---

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -n "$REPO_ROOT" ]]; then
  SCOPE="local"
  SCOPE_DIR="$REPO_ROOT"
  SCOPE_NAME=$(basename "$REPO_ROOT")
  GIT_FLAG=""  # local is default
else
  SCOPE="global"
  SCOPE_DIR=""
  SCOPE_NAME=""
  GIT_FLAG="--global"
fi

info "Scope: $SCOPE"
echo ""

# --- fetch profile ---

info "Fetching GitHub profile..."
NAME_DEFAULT=$(gh api user --jq '.name')
LOGIN=$(gh api user --jq '.login')
ID=$(gh api user --jq '.id')
NOREPLY="${ID}+${LOGIN}@users.noreply.github.com"

echo "  GitHub name: $NAME_DEFAULT"
echo "  login:       $LOGIN"
echo "  noreply:     $NOREPLY"
echo ""

# --- prompt for display name ---

if [[ -t 0 ]]; then
  read -p "Display name [$NAME_DEFAULT]: " NAME_INPUT
  NAME="${NAME_INPUT:-$NAME_DEFAULT}"
else
  NAME="$NAME_DEFAULT"
  info "Non-interactive mode, using: $NAME"
fi
echo ""

# --- apply config ---

set_config() {
  local key="$1" value="$2"
  local current
  if [[ "$SCOPE" == "local" ]]; then
    current=$(git -C "$REPO_ROOT" config "$key" 2>/dev/null || echo "(not set)")
  else
    current=$(git config --global "$key" 2>/dev/null || echo "(not set)")
  fi
  if [[ "$current" == "$value" ]]; then
    ok "$SCOPE $key already: $value"
  else
    info "$SCOPE $key: $current → $value"
    git config $GIT_FLAG "$key" "$value"
  fi
}

set_config "user.name" "$NAME"
set_config "user.email" "$NOREPLY"

if [[ "$SCOPE" == "global" ]]; then
  set_config "github.user" "$LOGIN"
fi

echo ""

if [[ "$SCOPE" == "local" ]]; then
  ok "git configured for $SCOPE_NAME: $NAME <$NOREPLY>"
else
  ok "git configured globally: $NAME <$NOREPLY>"
fi
