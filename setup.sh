#!/bin/bash

# Setup script for bye-bye-comments

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}bye-bye-comments Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if required tools are installed
echo -e "\n${YELLOW}Checking dependencies...${NC}"

if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ git is not installed${NC}"
    echo "Please install git first"
    exit 1
else
    echo -e "${GREEN}✓ git is installed${NC}"
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}⚠ cargo is not installed${NC}"
    echo "Cargo is recommended for Rust projects but not required for installation"
else
    echo -e "${GREEN}✓ cargo is installed${NC}"
fi

# Make scripts executable
echo -e "\n${YELLOW}Making scripts executable...${NC}"
chmod +x "$SCRIPT_DIR/bye-bye-comments.sh"
chmod +x "$SCRIPT_DIR/bye-bye-comments-daemon.sh"
chmod +x "$SCRIPT_DIR/run_tests.sh"
chmod +x "$SCRIPT_DIR/tests"/*.sh 2>/dev/null || true
echo -e "${GREEN}✓ Scripts are now executable${NC}"

# Create local bin directory if it doesn't exist
echo -e "\n${YELLOW}Setting up installation directory...${NC}"
mkdir -p ~/.local/bin
echo -e "${GREEN}✓ Created ~/.local/bin directory${NC}"

# Create symlink
echo -e "\n${YELLOW}Creating symlink...${NC}"
ln -sf "$SCRIPT_DIR/bye-bye-comments.sh" ~/.local/bin/bye-bye-comments
echo -e "${GREEN}✓ Created symlink at ~/.local/bin/bye-bye-comments${NC}"

# Check if .local/bin is in PATH
echo -e "\n${YELLOW}Checking PATH configuration...${NC}"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${YELLOW}Adding ~/.local/bin to PATH...${NC}"
    
    # Detect shell
    if [[ -n "${BASH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"  # Default to bashrc
    fi
    
    # Add to PATH if not already there
    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
        echo -e "${GREEN}✓ Added ~/.local/bin to PATH in $SHELL_RC${NC}"
        echo -e "${YELLOW}Note: Run 'source $SHELL_RC' or open a new terminal for PATH changes to take effect${NC}"
    else
        echo -e "${GREEN}✓ ~/.local/bin is already in PATH configuration${NC}"
    fi
else
    echo -e "${GREEN}✓ ~/.local/bin is already in PATH${NC}"
fi

# Test installation
echo -e "\n${YELLOW}Testing installation...${NC}"
if ~/.local/bin/bye-bye-comments help &> /dev/null; then
    echo -e "${GREEN}✓ bye-bye-comments is working correctly${NC}"
else
    echo -e "${RED}✗ Installation test failed${NC}"
    exit 1
fi

# Print success message
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\nYou can now use bye-bye-comments in any Rust project:"
echo -e "  ${BLUE}bye-bye-comments init${NC}      # Initialize in a Rust project"
echo -e "  ${BLUE}bye-bye-comments comment${NC}   # View code with comments"
echo -e "  ${BLUE}bye-bye-comments uncomment${NC} # View code without comments"
echo -e "  ${BLUE}bye-bye-comments daemon${NC}    # Start background sync"
echo -e "  ${BLUE}bye-bye-comments help${NC}      # Show all commands"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\n${YELLOW}Important:${NC} Run 'source ${SHELL_RC:-~/.bashrc}' or open a new terminal to use the command"
fi