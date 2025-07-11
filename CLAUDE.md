# bye-bye-comments Project Information

## Overview
bye-bye-comments is a CLI tool for Rust projects that maintains two synchronized versions of your codebase:
- One with all comments preserved (main branch)
- One with all comments stripped (no-comments branch)

This allows developers to switch between viewing code with full documentation and a cleaner, comment-free view while preserving Rust's incremental compilation artifacts.

## Architecture

### Core Components

1. **bye-bye-comments.sh** - Main CLI script
   - Handles all user commands (init, comment, uncomment, status, daemon, stop)
   - Manages git branch switching with stash preservation
   - Creates and maintains configuration files

2. **bye-bye-comments-daemon.sh** - Background sync daemon (v1)
   - Monitors file changes in real-time
   - Detects comment-only vs code changes
   - Automatically syncs comment-only changes between branches
   - Preserves compilation state for comment-only changes

3. **bye-bye-comments-daemon-v2.sh** - Enhanced daemon with bidirectional sync
   - Monitors all file changes in real-time
   - Syncs ALL changes between branches automatically
   - When syncing from `no-comments` to `main`, preserves existing comments
   - When syncing from `main` to `no-comments`, strips comments
   - Maintains file timestamps to avoid unnecessary recompilation
   - Tracks sync state to avoid redundant operations

### How It Works

1. **Dual Branch System**:
   - `main` branch: Original code with all comments
   - `no-comments` branch: Automatically maintained version without comments
   - Git stash used to preserve uncommitted changes during switches

2. **Comment Stripping**:
   - Uses sed patterns to remove:
     - Single-line comments (`//`)
     - Multi-line comments (`/* */`)
     - Doc comments (`///` and `//!`)
   - Preserves string literals that might contain comment-like patterns

3. **Smart Compilation Preservation**:
   - File timestamps are preserved during sync operations
   - Rust's target directory remains intact during branch switches
   - The v2 daemon ensures both branches have identical code (modulo comments)

4. **Bidirectional Sync (v2 daemon)**:
   - All changes made in either branch are automatically synced to the other
   - Code structure remains identical between branches
   - Comments are preserved in the main branch when syncing from no-comments
   - Comments are stripped when syncing from main to no-comments
   - Real-time monitoring ensures immediate synchronization

## Testing

Comprehensive integration tests are provided:
- `test_init.sh` - Tests initialization and setup
- `test_switching.sh` - Tests mode switching functionality
- `test_daemon.sh` - Tests daemon lifecycle
- `test_compilation.sh` - Tests compilation behavior

Run all tests with: `./run_tests.sh`

## Future Enhancements

1. **VS Code Extension Integration**:
   - Direct integration with VS Code for seamless switching
   - Keyboard shortcuts for comment/uncomment modes
   - Visual indicators for current mode

2. **Enhanced Comment Detection**:
   - Use proper Rust AST parsing instead of regex
   - Better handling of edge cases in string literals

3. **Performance Optimizations**:
   - Incremental comment stripping for large codebases
   - Parallel processing for multiple files

## Development Notes

- Always test changes with the provided test suite
- Maintain backwards compatibility with existing projects
- Follow shell script best practices (set -euo pipefail, proper quoting)
- Keep daemon lightweight to minimize system resource usage