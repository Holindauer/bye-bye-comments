#!/bin/bash

# Test the init command

source "$(dirname "$0")/test_helpers.sh"

test_init_creates_config() {
    create_test_rust_project
    
    # Run init
    $BYE_BYE_COMMENTS init
    
    # Check config file exists
    assert_file_exists ".bye-bye-comments" "Config file should be created"
    
    # Check gitignore entries
    assert_contains "$(cat .gitignore)" ".bye-bye-comments" "Config should be in gitignore"
    assert_contains "$(cat .gitignore)" ".bye-bye-comments-daemon.pid" "Daemon PID file should be in gitignore"
    assert_contains "$(cat .gitignore)" ".bye-bye-comments-daemon.log" "Daemon log file should be in gitignore"
}

test_init_creates_no_comments_branch() {
    create_test_rust_project
    
    # Run init
    $BYE_BYE_COMMENTS init
    
    # Check branch exists
    assert_branch_exists "no-comments" "no-comments branch should be created"
    
    # Check we're back on main
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    assert_equals "main" "$current_branch" "Should be back on main branch after init"
}

test_init_strips_comments_in_no_comments_branch() {
    create_test_rust_project
    
    # Run init
    $BYE_BYE_COMMENTS init
    
    # Switch to no-comments branch
    git checkout -q no-comments
    
    # Check main.rs has no comments
    local main_content=$(cat src/main.rs)
    assert_not_contains "$main_content" "// This is a test" "Single-line comments should be removed"
    assert_not_contains "$main_content" "/// Main function" "Doc comments should be removed"
    assert_not_contains "$main_content" "/* This is a" "Multi-line comments should be removed"
    assert_not_contains "$main_content" "// Print hello" "Inline comments should be removed"
    
    # Check code is preserved
    assert_contains "$main_content" "fn main()" "Code should be preserved"
    assert_contains "$main_content" "println!(\"Hello, world!\")" "String literals should be preserved"
    assert_contains "$main_content" "let x = 42" "Variable declarations should be preserved"
    
    # Switch back to main
    git checkout -q main
}

test_init_idempotent() {
    create_test_rust_project
    
    # Run init twice
    $BYE_BYE_COMMENTS init
    local output=$($BYE_BYE_COMMENTS init 2>&1)
    
    # Should handle gracefully
    assert_contains "$output" "Initialization complete" "Second init should complete successfully"
}

test_init_outside_git_repo() {
    # Don't create git repo
    mkdir test_no_git
    cd test_no_git
    
    # Run init - should fail
    local output=$($BYE_BYE_COMMENTS init 2>&1 || true)
    assert_contains "$output" "Not in a git repository" "Should error when not in git repo"
}

# Run all init tests
run_test "init_creates_config" test_init_creates_config
run_test "init_creates_no_comments_branch" test_init_creates_no_comments_branch
run_test "init_strips_comments_in_no_comments_branch" test_init_strips_comments_in_no_comments_branch
run_test "init_idempotent" test_init_idempotent
run_test "init_outside_git_repo" test_init_outside_git_repo