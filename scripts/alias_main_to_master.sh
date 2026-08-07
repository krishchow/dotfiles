#!/bin/bash
set -euo pipefail

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "Error: PROJECTS_DIR not found: $PROJECTS_DIR"
  exit 1
fi

for repo in "$PROJECTS_DIR"/*/; do
  [[ -d "$repo/.git" ]] || continue

  echo "Processing: $repo"
  pushd "$repo" > /dev/null || continue

  if git show-ref --verify --quiet refs/heads/master; then
    if git show-ref --verify --quiet refs/heads/main; then
      echo "  ⚠️  'main' already exists, skipping"
    else
      git symbolic-ref refs/heads/main refs/heads/master
      echo "  ✓ Created 'main' as alias to 'master'"
    fi
  else
    echo "  ℹ️  No 'master' branch found, skipping"
  fi

  popd > /dev/null
  echo ""
done
