#!/bin/bash

# Test compilation behavior with comment changes

source "$(dirname "$0")/test_helpers.sh"

test_comment_only_changes_no_recompile() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Build the project to create target directory
    cargo build --quiet
    
    # Get initial build timestamp
    local initial_timestamp=$(stat -c %Y target/debug/test-project 2>/dev/null || stat -f %m target/debug/test-project 2>/dev/null)
    
    # Sleep to ensure timestamp would change if rebuilt
    sleep 2
    
    # Make a comment-only change
    sed -i.bak 's/\/\/ Print hello world/\/\/ Print a greeting message/' src/main.rs || \
    sed -i '' 's/\/\/ Print hello world/\/\/ Print a greeting message/' src/main.rs
    rm -f src/main.rs.bak
    
    # Switch to uncomment mode (should preserve build)
    $BYE_BYE_COMMENTS uncomment
    
    # Build again
    cargo build --quiet
    
    # Get new timestamp
    local new_timestamp=$(stat -c %Y target/debug/test-project 2>/dev/null || stat -f %m target/debug/test-project 2>/dev/null)
    
    # Timestamps should be the same (no recompilation)
    assert_equals "$initial_timestamp" "$new_timestamp" "Binary should not be recompiled for comment-only changes"
}

test_code_changes_trigger_recompile() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Build the project
    cargo build --quiet
    
    # Get initial build timestamp
    local initial_timestamp=$(stat -c %Y target/debug/test-project 2>/dev/null || stat -f %m target/debug/test-project 2>/dev/null)
    
    # Sleep to ensure timestamp would change if rebuilt
    sleep 2
    
    # Make a code change
    sed -i.bak 's/let x = 42;/let x = 100;/' src/main.rs || \
    sed -i '' 's/let x = 42;/let x = 100;/' src/main.rs
    rm -f src/main.rs.bak
    
    # Build again
    cargo build --quiet
    
    # Get new timestamp
    local new_timestamp=$(stat -c %Y target/debug/test-project 2>/dev/null || stat -f %m target/debug/test-project 2>/dev/null)
    
    # Timestamps should be different (recompilation occurred)
    if [[ "$initial_timestamp" != "$new_timestamp" ]]; then
        echo -e "  ${GREEN}✓${NC} Binary was recompiled for code changes"
    else
        echo -e "  ${RED}✗${NC} Binary was not recompiled for code changes"
        return 1
    fi
}

test_switching_preserves_target() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Build in comment mode
    cargo build --quiet
    assert_file_exists "target/debug/test-project" "Binary should exist after build"
    
    # Switch to uncomment mode
    $BYE_BYE_COMMENTS uncomment
    assert_file_exists "target/debug/test-project" "Binary should still exist after switching"
    
    # Switch back to comment mode
    $BYE_BYE_COMMENTS comment
    assert_file_exists "target/debug/test-project" "Binary should still exist after switching back"
}

test_cargo_check_with_comments_stripped() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Switch to uncomment mode
    $BYE_BYE_COMMENTS uncomment
    
    # Run cargo check - should succeed even without comments
    local output=$(cargo check 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Cargo check should succeed without comments"
}

# Run all compilation tests
run_test "comment_only_changes_no_recompile" test_comment_only_changes_no_recompile
run_test "code_changes_trigger_recompile" test_code_changes_trigger_recompile
run_test "switching_preserves_target" test_switching_preserves_target
run_test "cargo_check_with_comments_stripped" test_cargo_check_with_comments_stripped