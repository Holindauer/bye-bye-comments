# bye-bye-comments

A CLI tool for Rust projects that maintains two synchronized versions of your codebase - one with comments and one without. Perfect for developers who want to switch between viewing code with full documentation and a cleaner, comment-free view.

## Features

- **Dual Branch Management**: Automatically maintains `main` (with comments) and `no-comments` branches
- **Smart Compilation**: Only recompiles when actual code changes, not when comments are modified
- **Background Daemon**: Monitors and syncs comment-only changes between branches automatically
- **Simple Commands**: Switch between modes with `comment` and `uncomment` commands
- **Git Integration**: Built on top of Git for reliable version control

## Installation

### Quick Setup (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/yourusername/bye-bye-comments.git
cd bye-bye-comments
```

2. Run the setup script:
```bash
./setup.sh
```

The setup script will:
- Check for required dependencies (git, cargo)
- Make all scripts executable
- Create a symlink in `~/.local/bin`
- Add `~/.local/bin` to your PATH if needed
- Test the installation

### Manual Installation

If you prefer to install manually:

1. Clone the repository and make scripts executable:
```bash
git clone https://github.com/yourusername/bye-bye-comments.git
cd bye-bye-comments
chmod +x bye-bye-comments.sh bye-bye-comments-daemon.sh
```

2. Create a symlink in your local bin directory:
```bash
mkdir -p ~/.local/bin
ln -s $(pwd)/bye-bye-comments.sh ~/.local/bin/bye-bye-comments
```

3. Add `~/.local/bin` to your PATH if not already there:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

### Initialize in Your Rust Project

Navigate to your Rust project and initialize bye-bye-comments:

```bash
cd /path/to/your/rust/project
bye-bye-comments init
```

This will:
- Create a `no-comments` branch with all comments stripped
- Set up configuration files
- Update `.gitignore` with tool-specific files

### Switch Between Modes

View code with comments:
```bash
bye-bye-comments comment
```

View code without comments:
```bash
bye-bye-comments uncomment
```

### Start the Background Daemon

The daemon monitors file changes and intelligently syncs between branches:

```bash
bye-bye-comments daemon
```

When the daemon is running:
- Comment-only changes won't trigger recompilation
- Code changes are detected and require manual syncing
- Changes are automatically synchronized between branches

Stop the daemon:
```bash
bye-bye-comments stop
```

### Check Status

View current mode and daemon status:
```bash
bye-bye-comments status
```

## How It Works

1. **Branch Structure**: 
   - `main` branch: Contains your code with all comments
   - `no-comments` branch: Automatically maintained version without comments

2. **Smart Syncing**:
   - The daemon detects when only comments have changed
   - Comment-only changes are synced without affecting compilation
   - Code changes are flagged for manual review

3. **Compilation Optimization**:
   - Rust's incremental compilation isn't triggered by comment-only changes
   - Switching between comment/uncomment modes preserves build artifacts

## VS Code Extension (Future)

This tool is designed to be integrated into a VS Code extension, allowing seamless switching between comment modes directly from the editor.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Troubleshooting

### "not initialized" error after switching branches

If you get an "not initialized" error after using the tool, it's likely because the config file was lost during branch switching. The tool now automatically recreates the config file when needed. Simply run your command again and it should work.

### Config file conflicts during init

If you see errors about `.bye-bye-comments` file conflicts during initialization, the latest version handles this automatically by stashing uncommitted files before creating branches.

### Daemon not stopping

If the daemon doesn't stop properly, you can manually kill it:
```bash
kill $(cat .bye-bye-comments-daemon.pid)
rm .bye-bye-comments-daemon.pid
```

## License

MIT License - see LICENSE file for details 
