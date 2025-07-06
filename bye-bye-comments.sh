#!/bin/bash

# bye-bye-comments - A tool to manage Rust projects with and without comments
# Uses git branches to maintain two versions of the codebase

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAIN_BRANCH="main"
NO_COMMENTS_BRANCH="no-comments"
DAEMON_PID_FILE=".bye-bye-comments-daemon.pid"
CONFIG_FILE=".bye-bye-comments"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository!"
        exit 1
    fi
}

# Check if the tool is initialized in this repository
check_initialized() {
    # Check if we have the no-comments branch as a sign of initialization
    if ! git show-ref --verify --quiet "refs/heads/$NO_COMMENTS_BRANCH"; then
        log_error "bye-bye-comments is not initialized in this repository."
        log_info "Run 'bye-bye-comments init' to set up."
        exit 1
    fi
    
    # Recreate config file if missing (can happen after branch switches)
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# bye-bye-comments configuration
MAIN_BRANCH=$MAIN_BRANCH
NO_COMMENTS_BRANCH=$NO_COMMENTS_BRANCH
EOF
    fi
}

# Strip comments from Rust files
strip_rust_comments() {
    local file="$1"
    local temp_file=$(mktemp)
    
    # Use sed to remove comments while preserving strings
    # This is a simplified version - a more robust solution would use a proper parser
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

# Restore comments from the main branch
restore_comments() {
    local file="$1"
    git checkout "$MAIN_BRANCH" -- "$file" 2>/dev/null || true
}

# Initialize the tool in the current repository
init_tool() {
    check_git_repo
    
    log_info "Initializing bye-bye-comments..."
    
    # Create config file
    cat > "$CONFIG_FILE" << EOF
# bye-bye-comments configuration
MAIN_BRANCH=$MAIN_BRANCH
NO_COMMENTS_BRANCH=$NO_COMMENTS_BRANCH
EOF
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    # Create no-comments branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$NO_COMMENTS_BRANCH"; then
        log_info "Creating $NO_COMMENTS_BRANCH branch..."
        
        # Save current work
        local stash_created=false
        if ! git diff-index --quiet HEAD -- || [[ -n $(git ls-files --others --exclude-standard) ]]; then
            git stash push -u -m "bye-bye-comments: init stash" > /dev/null 2>&1
            stash_created=true
        fi
        
        git checkout -b "$NO_COMMENTS_BRANCH"
        
        # Strip comments from all Rust files
        log_info "Stripping comments from Rust files..."
        find . -name "*.rs" -type f | while read -r file; do
            strip_rust_comments "$file"
        done
        
        # Commit the changes
        git add -A
        git commit -m "Remove comments from Rust files" || true
        
        # Switch back to original branch
        git checkout "$current_branch"
        
        # Restore stashed changes if any
        if [[ "$stash_created" == true ]]; then
            git stash pop > /dev/null 2>&1 || true
        fi
    else
        log_info "bye-bye-comments already initialized (no-comments branch exists)"
    fi
    
    # Add bye-bye-comments files to gitignore
    local gitignore_updated=false
    
    if ! grep -q "^$CONFIG_FILE$" .gitignore 2>/dev/null; then
        echo "$CONFIG_FILE" >> .gitignore
        gitignore_updated=true
    fi
    
    if ! grep -q "^$DAEMON_PID_FILE$" .gitignore 2>/dev/null; then
        echo "$DAEMON_PID_FILE" >> .gitignore
        gitignore_updated=true
    fi
    
    if ! grep -q "^.bye-bye-comments-daemon.log$" .gitignore 2>/dev/null; then
        echo ".bye-bye-comments-daemon.log" >> .gitignore
        gitignore_updated=true
    fi
    
    if ! grep -q "^.bye-bye-comments-sync-state$" .gitignore 2>/dev/null; then
        echo ".bye-bye-comments-sync-state" >> .gitignore
        gitignore_updated=true
    fi
    
    # Commit gitignore changes if any were made
    if [[ "$gitignore_updated" == true ]]; then
        git add .gitignore
        git commit -m "Add bye-bye-comments files to gitignore" || true
    fi
    
    log_info "Initialization complete!"
}

# Get current viewing mode
get_current_mode() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" == "$NO_COMMENTS_BRANCH" ]]; then
        echo "uncomment"
    else
        echo "comment"
    fi
}

# Switch to comment mode (main branch with comments)
switch_to_comment() {
    check_initialized
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    if [[ "$current_branch" == "$MAIN_BRANCH" ]]; then
        log_info "Already in comment mode"
        return
    fi
    
    log_info "Switching to comment mode..."
    
    # Stash any uncommitted changes
    local stash_created=false
    if ! git diff-index --quiet HEAD --; then
        git stash push -m "bye-bye-comments: temporary stash"
        stash_created=true
    fi
    
    # Switch to main branch
    git checkout "$MAIN_BRANCH"
    
    # Apply stash if created
    if [[ "$stash_created" == true ]]; then
        git stash pop
    fi
    
    log_info "Switched to comment mode"
}

# Switch to uncomment mode (no-comments branch)
switch_to_uncomment() {
    check_initialized
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    if [[ "$current_branch" == "$NO_COMMENTS_BRANCH" ]]; then
        log_info "Already in uncomment mode"
        return
    fi
    
    log_info "Switching to uncomment mode..."
    
    # Stash any uncommitted changes
    local stash_created=false
    if ! git diff-index --quiet HEAD --; then
        git stash push -m "bye-bye-comments: temporary stash"
        stash_created=true
    fi
    
    # Switch to no-comments branch
    git checkout "$NO_COMMENTS_BRANCH"
    
    # Apply stash if created
    if [[ "$stash_created" == true ]]; then
        git stash pop
    fi
    
    log_info "Switched to uncomment mode"
}

# Display current status
show_status() {
    check_initialized
    
    local mode=$(get_current_mode)
    local daemon_status="stopped"
    
    if [[ -f "$DAEMON_PID_FILE" ]]; then
        local pid=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            daemon_status="running (PID: $pid)"
        fi
    fi
    
    echo -e "${BLUE}bye-bye-comments status:${NC}"
    echo -e "  Current mode: ${GREEN}$mode${NC}"
    echo -e "  Daemon: $daemon_status"
}

# Display help
show_help() {
    cat << EOF
bye-bye-comments - Manage Rust projects with and without comments

Usage: bye-bye-comments [COMMAND]

Commands:
    init        Initialize bye-bye-comments in the current repository
    comment     Switch to comment mode (view code with comments)
    uncomment   Switch to uncomment mode (view code without comments)
    status      Show current mode and daemon status
    daemon      Start the background daemon for smart syncing
    stop        Stop the background daemon
    help        Show this help message

Examples:
    bye-bye-comments init          # Initialize in current repo
    bye-bye-comments comment       # Switch to view with comments
    bye-bye-comments uncomment     # Switch to view without comments
    bye-bye-comments daemon        # Start background sync daemon
EOF
}

# Main command parsing
case "${1:-help}" in
    init)
        init_tool
        ;;
    comment)
        switch_to_comment
        ;;
    uncomment)
        switch_to_uncomment
        ;;
    status)
        show_status
        ;;
    daemon)
        check_initialized
        
        # Check if daemon is already running
        if [[ -f "$DAEMON_PID_FILE" ]]; then
            local pid=$(cat "$DAEMON_PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "Daemon is already running (PID: $pid)"
                exit 0
            fi
        fi
        
        # Start the daemon (use v2 if available, fallback to v1)
        local daemon_script="$(dirname "$0")/bye-bye-comments-daemon-v2.sh"
        if [[ ! -f "$daemon_script" ]]; then
            daemon_script="$(dirname "$0")/bye-bye-comments-daemon.sh"
        fi
        
        log_info "Starting bye-bye-comments daemon..."
        nohup "$daemon_script" > /dev/null 2>&1 &
        sleep 1  # Give daemon time to start
        
        if [[ -f "$DAEMON_PID_FILE" ]]; then
            local pid=$(cat "$DAEMON_PID_FILE")
            log_info "Daemon started successfully (PID: $pid)"
        else
            log_error "Failed to start daemon"
            exit 1
        fi
        ;;
    stop)
        check_initialized
        
        if [[ ! -f "$DAEMON_PID_FILE" ]]; then
            log_info "Daemon is not running"
            exit 0
        fi
        
        local pid=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping daemon (PID: $pid)..."
            kill "$pid"
            rm -f "$DAEMON_PID_FILE"
            log_info "Daemon stopped"
        else
            log_warning "Daemon PID file exists but process is not running"
            rm -f "$DAEMON_PID_FILE"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac