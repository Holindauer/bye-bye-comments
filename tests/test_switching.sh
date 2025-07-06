#!/bin/bash

# Test comment/uncomment mode switching

source "$(dirname "$0")/test_helpers.sh"

test_switch_to_uncomment() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Start on main branch
    assert_equals "main" "$(git rev-parse --abbrev-ref HEAD)" "Should start on main branch"
    
    # Switch to uncomment mode
    $BYE_BYE_COMMENTS uncomment
    
    # Check we're on no-comments branch
    assert_equals "no-comments" "$(git rev-parse --abbrev-ref HEAD)" "Should be on no-comments branch"
    
    # Check files have no comments
    local main_content=$(cat src/main.rs)
    assert_not_contains "$main_content" "// This is a test" "Comments should be removed"
    assert_contains "$main_content" "fn main()" "Code should be preserved"
}

test_switch_to_comment() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Switch to uncomment mode first
    $BYE_BYE_COMMENTS uncomment
    
    # Then switch back to comment mode
    $BYE_BYE_COMMENTS comment
    
    # Check we're on main branch
    assert_equals "main" "$(git rev-parse --abbrev-ref HEAD)" "Should be on main branch"
    
    # Check files have comments
    local main_content=$(cat src/main.rs)
    assert_contains "$main_content" "// This is a test" "Comments should be present"
    assert_contains "$main_content" "/// Main function" "Doc comments should be present"
}

test_switch_idempotent() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Switch to uncomment twice
    $BYE_BYE_COMMENTS uncomment
    local output=$($BYE_BYE_COMMENTS uncomment 2>&1)
    assert_contains "$output" "Already in uncomment mode" "Should recognize already in mode"
    
    # Switch to comment twice
    $BYE_BYE_COMMENTS comment
    output=$($BYE_BYE_COMMENTS comment 2>&1)
    assert_contains "$output" "Already in comment mode" "Should recognize already in mode"
}

test_switch_with_uncommitted_changes() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Make uncommitted changes
    echo "// New comment" >> src/main.rs
    
    # Switch to uncomment - should stash changes
    $BYE_BYE_COMMENTS uncomment
    
    # Check we're on no-comments branch
    assert_equals "no-comments" "$(git rev-parse --abbrev-ref HEAD)" "Should switch with uncommitted changes"
    
    # Switch back
    $BYE_BYE_COMMENTS comment
    
    # Check changes are preserved
    local main_content=$(cat src/main.rs)
    assert_contains "$main_content" "// New comment" "Uncommitted changes should be preserved"
}

test_status_command() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Check status in comment mode
    local output=$($BYE_BYE_COMMENTS status)
    assert_contains "$output" "Current mode: comment" "Should show comment mode"
    assert_contains "$output" "Daemon: stopped" "Should show daemon stopped"
    
    # Switch to uncomment and check
    $BYE_BYE_COMMENTS uncomment
    output=$($BYE_BYE_COMMENTS status)
    assert_contains "$output" "Current mode: uncomment" "Should show uncomment mode"
}

test_switch_without_init() {
    create_test_rust_project
    
    # Try to switch without init
    local output=$($BYE_BYE_COMMENTS uncomment 2>&1 || true)
    assert_contains "$output" "not initialized" "Should error when not initialized"
}

# Run all switching tests
run_test "switch_to_uncomment" test_switch_to_uncomment
run_test "switch_to_comment" test_switch_to_comment
run_test "switch_idempotent" test_switch_idempotent
run_test "switch_with_uncommitted_changes" test_switch_with_uncommitted_changes
run_test "status_command" test_status_command
run_test "switch_without_init" test_switch_without_init