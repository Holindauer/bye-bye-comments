#!/bin/bash

# Test helper functions for bye-bye-comments

set -euo pipefail

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory setup
TEST_ROOT_DIR="/tmp/bye-bye-comments-tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYE_BYE_COMMENTS="$SCRIPT_DIR/bye-bye-comments.sh"

# Test framework functions
setup_test() {
    local test_name="$1"
    echo -e "\n${BLUE}Running test: $test_name${NC}"
    ((TESTS_RUN++))
    
    # Create unique test directory
    TEST_DIR="$TEST_ROOT_DIR/$test_name-$$"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
}

teardown_test() {
    # Kill any running daemon
    if [[ -f .bye-bye-comments-daemon.pid ]]; then
        local pid=$(cat .bye-bye-comments-daemon.pid)
        kill "$pid" 2>/dev/null || true
    fi
    
    # Clean up test directory
    cd "$TEST_ROOT_DIR"
    rm -rf "$TEST_DIR"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        echo -e "    Expected: $expected"
        echo -e "    Actual:   $actual"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        echo -e "    Looking for: $needle"
        echo -e "    In:          $haystack"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        echo -e "    Found: $needle"
        echo -e "    In:    $haystack"
        return 1
    fi
}

assert_branch_exists() {
    local branch="$1"
    local message="${2:-Branch should exist: $branch}"
    
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    setup_test "$test_name"
    
    # Run the test and capture result
    if $test_function; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        ((TESTS_PASSED++))
        teardown_test
        return 0
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        ((TESTS_FAILED++))
        teardown_test
        return 1
    fi
}

# Create a sample Rust project for testing
create_test_rust_project() {
    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create Cargo.toml
    cat > Cargo.toml << 'EOF'
[package]
name = "test-project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
    
    # Create src directory
    mkdir -p src
    
    # Create main.rs with comments
    cat > src/main.rs << 'EOF'
// This is a test Rust project
// Used for testing bye-bye-comments

/// Main function documentation
/// This is a multi-line doc comment
fn main() {
    // Print hello world
    println!("Hello, world!"); // inline comment
    
    /* This is a 
       multi-line comment */
    let x = 42;
    
    /* Another comment */ let y = x + 1;
    
    // Final comment
    println!("x = {}, y = {}", x, y);
}

/// Helper function with documentation
fn helper() {
    // This function does nothing
}
EOF
    
    # Create lib.rs with comments
    cat > src/lib.rs << 'EOF'
//! Library documentation comment
//! This is a test library

/// A test module
mod test_mod {
    /// Test function in module
    pub fn test_fn() {
        // Implementation here
        let _value = 1; // with comment
    }
}

/* Block comment at end */
EOF
    
    # Commit initial state
    git add .
    git commit -q -m "Initial commit"
}

# Print test summary
print_test_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Clean up any leftover test directories
cleanup_all_tests() {
    rm -rf "$TEST_ROOT_DIR"
}

# Initialize test environment
mkdir -p "$TEST_ROOT_DIR"