#!/bin/bash
# Fetch updates for all git repos under ~/projects
# Runs with random jitter between repos to avoid thundering herd

PROJECTS_DIR="$HOME/projects"
LOG_FILE="$HOME/logs/repo-sync.log"
MAX_JITTER_SECONDS=30

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Starting repo sync ==="

for repo in "$PROJECTS_DIR"/*/; do
    [[ "$repo" == *"/sync/" ]] && continue

    if [ -d "$repo/.git" ]; then
        jitter=$((RANDOM % MAX_JITTER_SECONDS))
        log "Waiting ${jitter}s before updating $(basename "$repo")"
        sleep "$jitter"

        cd "$repo" || continue

        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        if [ -z "$default_branch" ]; then
            default_branch="main"
        fi

        log "Fetching $(basename "$repo") (default branch: $default_branch)"

        if git fetch origin "$default_branch" 2>&1 | while read -r line; do log "  $line"; done; then
            log "  Successfully fetched $(basename "$repo")"
        else
            log "  Failed to fetch $(basename "$repo")"
        fi
    fi
done

log "=== Repo sync complete ==="
