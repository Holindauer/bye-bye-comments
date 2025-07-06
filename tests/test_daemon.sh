#!/bin/bash

# Test daemon functionality

source "$(dirname "$0")/test_helpers.sh"

test_daemon_start() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Start daemon
    $BYE_BYE_COMMENTS daemon
    
    # Give daemon time to start
    sleep 2
    
    # Check PID file exists
    assert_file_exists ".bye-bye-comments-daemon.pid" "Daemon PID file should exist"
    
    # Check daemon is running
    local pid=$(cat .bye-bye-comments-daemon.pid)
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Daemon process is running"
    else
        echo -e "  ${RED}✗${NC} Daemon process is not running"
        return 1
    fi
    
    # Check log file exists
    assert_file_exists ".bye-bye-comments-daemon.log" "Daemon log file should exist"
    
    # Stop daemon for cleanup
    $BYE_BYE_COMMENTS stop
}

test_daemon_stop() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Start daemon
    $BYE_BYE_COMMENTS daemon
    sleep 2
    
    local pid=$(cat .bye-bye-comments-daemon.pid)
    
    # Stop daemon
    $BYE_BYE_COMMENTS stop
    
    # Check PID file removed
    assert_file_not_exists ".bye-bye-comments-daemon.pid" "Daemon PID file should be removed"
    
    # Check process stopped
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Daemon process stopped"
    else
        echo -e "  ${RED}✗${NC} Daemon process still running"
        kill "$pid" 2>/dev/null || true
        return 1
    fi
}

test_daemon_already_running() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Start daemon
    $BYE_BYE_COMMENTS daemon
    sleep 2
    
    # Try to start again
    local output=$($BYE_BYE_COMMENTS daemon 2>&1)
    assert_contains "$output" "already running" "Should detect daemon already running"
    
    # Stop daemon for cleanup
    $BYE_BYE_COMMENTS stop
}

test_daemon_status_running() {
    create_test_rust_project
    $BYE_BYE_COMMENTS init
    
    # Start daemon
    $BYE_BYE_COMMENTS daemon
    sleep 2
    
    # Check status
    local output=$($BYE_BYE_COMMENTS status)
    assert_contains "$output" "Daemon: running" "Status should show daemon running"
    
    # Stop daemon for cleanup
    $BYE_BYE_COMMENTS stop
}

test_daemon_without_init() {
    create_test_rust_project
    
    # Try to start daemon without init
    local output=$($BYE_BYE_COMMENTS daemon 2>&1 || true)
    assert_contains "$output" "not initialized" "Should error when not initialized"
}

# Run all daemon tests
run_test "daemon_start" test_daemon_start
run_test "daemon_stop" test_daemon_stop
run_test "daemon_already_running" test_daemon_already_running
run_test "daemon_status_running" test_daemon_status_running
run_test "daemon_without_init" test_daemon_without_init