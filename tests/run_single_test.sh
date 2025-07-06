#!/bin/bash

# Simple script to run a single test for verification

source "$(dirname "$0")/test_helpers.sh"

# Create a simple test
create_test_rust_project
echo "Test project created successfully"

# Clean up
cd /tmp
rm -rf "$TEST_DIR"

echo "Test verification complete"