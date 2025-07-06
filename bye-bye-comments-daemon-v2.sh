#!/bin/bash

# bye-bye-comments-daemon-v2 - Enhanced daemon with bidirectional sync

set -euo pipefail

# Configuration
MAIN_BRANCH="main"
NO_COMMENTS_BRANCH="no-comments"
DAEMON_PID_FILE=".bye-bye-comments-daemon.pid"
DAEMON_LOG_FILE=".bye-bye-comments-daemon.log"
CHECK_INTERVAL=1  # Check for changes every second
SYNC_STATE_FILE=".bye-bye-comments-sync-state"

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
    
    # Preserve file permissions and timestamp
    chmod --reference="$file" "$temp_file"
    touch -r "$file" "$temp_file"
    mv "$temp_file" "$file"
}

# Extract comments from a file (for preserving them)
extract_comments() {
    local file="$1"
    local output_file="$2"
    
    # This extracts comment positions and content
    # Using a more sophisticated approach to track line numbers
    perl -ne '
        if (m{//(.*)$}) {
            print "$.:SINGLE:$1\n";
        }
        while (m{/\*([^*]|\*(?!/))*\*/}g) {
            my $comment = $&;
            print "$.:MULTI:$comment\n";
        }
    ' "$file" > "$output_file"
}

# Merge code changes while preserving comments
merge_with_comments() {
    local no_comments_file="$1"
    local main_file="$2"
    local output_file="$3"
    
    # Extract comments from main branch file
    local comments_file=$(mktemp)
    extract_comments "$main_file" "$comments_file"
    
    # Start with the no-comments version (has latest code)
    cp "$no_comments_file" "$output_file"
    
    # Re-apply comments from main branch
    # This is a simplified version - a production version would need better merging
    while IFS=: read -r line_num type comment; do
        if [[ "$type" == "SINGLE" ]]; then
            # Add single-line comment at end of line
            sed -i "${line_num}s|$| //${comment}|" "$output_file" 2>/dev/null || true
        fi
        # Multi-line comments are harder to re-insert accurately
    done < "$comments_file"
    
    rm "$comments_file"
}

# Get file hash for change detection
get_file_hash() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo "MISSING"
    fi
}

# Load sync state
load_sync_state() {
    if [[ -f "$SYNC_STATE_FILE" ]]; then
        source "$SYNC_STATE_FILE"
    else
        declare -gA SYNC_STATE
    fi
}

# Save sync state
save_sync_state() {
    {
        for key in "${!SYNC_STATE[@]}"; do
            echo "SYNC_STATE[$key]='${SYNC_STATE[$key]}'"
        done
    } > "$SYNC_STATE_FILE"
}

# Sync a single file between branches
sync_file() {
    local file="$1"
    local current_branch="$2"
    local other_branch="$3"
    
    log_info "Syncing $file from $current_branch to $other_branch"
    
    # Create a temporary workspace
    local temp_dir=$(mktemp -d)
    
    # Get the current file
    cp "$file" "$temp_dir/current"
    
    # Switch to other branch and sync
    git checkout -q "$other_branch"
    
    if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
        # Syncing from main to no-comments: strip comments from the updated file
        cp "$temp_dir/current" "$file"
        strip_rust_comments "$file"
    else
        # Syncing from no-comments to main: preserve existing comments
        if [[ -f "$file" ]]; then
            # Merge code changes while preserving comments
            merge_with_comments "$temp_dir/current" "$file" "$temp_dir/merged"
            cp "$temp_dir/merged" "$file"
        else
            # New file - just copy it
            cp "$temp_dir/current" "$file"
        fi
    fi
    
    # Commit the change
    git add "$file"
    git commit -q -m "Sync from $current_branch: $file" || true
    
    # Switch back
    git checkout -q "$current_branch"
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Monitor and sync changes
monitor_changes() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    # Only sync if on main or no-comments branch
    if [[ "$current_branch" != "$MAIN_BRANCH" && "$current_branch" != "$NO_COMMENTS_BRANCH" ]]; then
        return
    fi
    
    local other_branch=""
    if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
        other_branch="$NO_COMMENTS_BRANCH"
    else
        other_branch="$MAIN_BRANCH"
    fi
    
    # Check all Rust files for changes
    while IFS= read -r -d '' file; do
        # Skip if file is in target directory
        if [[ "$file" =~ ^target/ ]]; then
            continue
        fi
        
        local current_hash=$(get_file_hash "$file")
        local state_key="${current_branch}:${file}"
        
        # Check if file has changed
        if [[ "${SYNC_STATE[$state_key]:-}" != "$current_hash" ]]; then
            log_info "Detected change in $file on $current_branch"
            
            # Sync the file
            sync_file "$file" "$current_branch" "$other_branch"
            
            # Update state
            SYNC_STATE[$state_key]="$current_hash"
            SYNC_STATE["${other_branch}:${file}"]=$(get_file_hash "$file")
            save_sync_state
        fi
    done < <(find . -name "*.rs" -type f -print0 2>/dev/null)
}

# Main daemon loop
run_daemon() {
    # Write PID file
    echo $$ > "$DAEMON_PID_FILE"
    
    log_info "bye-bye-comments daemon v2 started (PID: $$)"
    log_info "Bidirectional sync enabled"
    
    # Load initial state
    declare -gA SYNC_STATE
    load_sync_state
    
    # Set up signal handlers
    trap 'log_info "Daemon stopped"; rm -f "$DAEMON_PID_FILE" "$SYNC_STATE_FILE"; exit 0' SIGTERM SIGINT
    
    # Initial scan to populate state
    log_info "Performing initial scan..."
    monitor_changes
    
    # Main loop
    while true; do
        monitor_changes
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

# Clean up old sync state if switching daemon versions
rm -f "$SYNC_STATE_FILE"

# Start daemon
echo "Starting bye-bye-comments daemon v2..."
echo "Bidirectional sync is enabled - all code changes will sync between branches"
run_daemon &