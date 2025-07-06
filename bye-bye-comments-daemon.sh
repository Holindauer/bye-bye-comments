#!/bin/bash

# bye-bye-comments-daemon - Background daemon for smart syncing between branches

set -euo pipefail

# Configuration
MAIN_BRANCH="main"
NO_COMMENTS_BRANCH="no-comments"
DAEMON_PID_FILE=".bye-bye-comments-daemon.pid"
DAEMON_LOG_FILE=".bye-bye-comments-daemon.log"
CHECK_INTERVAL=1  # Check for changes every second

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$DAEMON_LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$DAEMON_LOG_FILE"
}

# Strip comments from a single Rust file
strip_rust_comments() {
    local file="$1"
    local temp_file=$(mktemp)
    
    sed -E '
        # Remove single-line comments that are not in strings
        s|//[^"]*$||
        # Remove multi-line comments
        :a
        s|/\*[^*]*\*+([^/*][^*]*\*+)*/||g
        ta
    ' "$file" > "$temp_file"
    
    # Preserve file permissions
    chmod --reference="$file" "$temp_file"
    mv "$temp_file" "$file"
}

# Check if a file has only comment changes
has_only_comment_changes() {
    local file="$1"
    local branch="$2"
    
    # Create temporary files for comparison
    local temp1=$(mktemp)
    local temp2=$(mktemp)
    
    # Get the file content from the specified branch and strip comments
    git show "$branch:$file" 2>/dev/null | sed -E '
        s|//[^"]*$||
        :a
        s|/\*[^*]*\*+([^/*][^*]*\*+)*/||g
        ta
    ' > "$temp1"
    
    # Strip comments from current file
    sed -E '
        s|//[^"]*$||
        :a
        s|/\*[^*]*\*+([^/*][^*]*\*+)*/||g
        ta
    ' "$file" > "$temp2"
    
    # Compare the files
    if diff -q "$temp1" "$temp2" > /dev/null; then
        rm "$temp1" "$temp2"
        return 0  # Only comment changes
    else
        rm "$temp1" "$temp2"
        return 1  # Code changes detected
    fi
}

# Sync changes between branches
sync_changes() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local other_branch=""
    
    if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
        other_branch="$NO_COMMENTS_BRANCH"
    elif [[ "$current_branch" == "$NO_COMMENTS_BRANCH" ]]; then
        other_branch="$MAIN_BRANCH"
    else
        return  # Not on a managed branch
    fi
    
    # Get list of modified files
    local modified_files=$(git diff --name-only)
    
    if [[ -z "$modified_files" ]]; then
        return  # No changes to sync
    fi
    
    # Process each modified file
    while IFS= read -r file; do
        if [[ ! "$file" =~ \.rs$ ]]; then
            continue  # Only process Rust files
        fi
        
        if has_only_comment_changes "$file" "$other_branch"; then
            log_info "Detected comment-only change in $file"
            
            # Create a temporary stash of current changes
            git stash push -q -m "daemon: temporary stash for $file" -- "$file"
            
            # Switch to other branch
            git checkout -q "$other_branch"
            
            # Apply the changes based on branch
            if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
                # We're syncing from main to no-comments, so strip comments
                git checkout -q "$current_branch" -- "$file"
                strip_rust_comments "$file"
            else
                # We're syncing from no-comments to main, so restore with comments
                git stash pop -q
            fi
            
            # Commit the change
            git add "$file"
            git commit -q -m "Sync comment changes from $current_branch: $file"
            
            # Switch back
            git checkout -q "$current_branch"
            
            # Restore the working changes
            if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
                git stash pop -q
            fi
            
            log_info "Synced $file to $other_branch"
        else
            log_info "Detected code changes in $file - manual sync required"
        fi
    done <<< "$modified_files"
}

# Main daemon loop
run_daemon() {
    # Write PID file
    echo $$ > "$DAEMON_PID_FILE"
    
    log_info "bye-bye-comments daemon started (PID: $$)"
    
    # Set up signal handlers
    trap 'log_info "Daemon stopped"; rm -f "$DAEMON_PID_FILE"; exit 0' SIGTERM SIGINT
    
    # Main loop
    while true; do
        sync_changes
        sleep "$CHECK_INTERVAL"
    done
}

# Check if daemon is already running
if [[ -f "$DAEMON_PID_FILE" ]]; then
    pid=$(cat "$DAEMON_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "Daemon is already running (PID: $pid)"
        exit 1
    else
        rm -f "$DAEMON_PID_FILE"
    fi
fi

# Start daemon
echo "Starting bye-bye-comments daemon..."
run_daemon &