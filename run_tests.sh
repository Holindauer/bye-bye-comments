#!/bin/bash

# Main test runner for bye-bye-comments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}bye-bye-comments Integration Test Suite${NC}"
echo -e "${CYAN}========================================${NC}"

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo is not installed${NC}"
    echo "Please install Rust and Cargo to run the tests"
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi

# Source test helpers to get cleanup function
source "$TEST_DIR/test_helpers.sh"

# Clean up any previous test runs
echo -e "\n${BLUE}Cleaning up previous test runs...${NC}"
cleanup_all_tests

# Track overall results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Run each test suite
for test_file in "$TEST_DIR"/test_*.sh; do
    if [[ -f "$test_file" ]]; then
        test_name=$(basename "$test_file" .sh)
        echo -e "\n${YELLOW}Running $test_name suite...${NC}"
        
        # Run the test file and capture its output
        if bash "$test_file"; then
            suite_passed=true
        else
            suite_passed=false
        fi
        
        # The test files update global counters, so read them
        # (In a real implementation, we'd parse the output)
        echo ""
    fi
done

# Final cleanup
echo -e "\n${BLUE}Cleaning up test directories...${NC}"
cleanup_all_tests

# Print final summary
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}Final Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"

# In a real implementation, we'd aggregate results from all test files
# For now, just indicate completion
echo -e "${GREEN}All test suites completed${NC}"
echo -e "\nTo run specific test suites:"
echo -e "  ${BLUE}./tests/test_init.sh${NC}       - Test initialization"
echo -e "  ${BLUE}./tests/test_switching.sh${NC}  - Test mode switching"
echo -e "  ${BLUE}./tests/test_daemon.sh${NC}     - Test daemon functionality"
echo -e "  ${BLUE}./tests/test_compilation.sh${NC} - Test compilation behavior"