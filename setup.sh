#!/bin/bash

set -e

echo "Setting up shift-shift-tab-search for Hammerspoon..."

# Install Hammerspoon if not already installed
if ! brew list --cask hammerspoon &> /dev/null; then
    echo "Installing Hammerspoon..."
    brew install hammerspoon --cask
else
    echo "Hammerspoon is already installed"
fi

# Create Hammerspoon config directory if it doesn't exist
CONFIG_DIR="$HOME/.hammerspoon"
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating Hammerspoon config directory..."
    mkdir -p "$CONFIG_DIR"
fi

# Copy init.lua to Hammerspoon config directory
echo "Copying init.lua to Hammerspoon config directory..."
cp init.lua "$CONFIG_DIR/init.lua"

echo ""
echo "Setup complete! Please open Hammerspoon and complete the basic setup."
echo "Double-tap Shift in Chrome to open tab search (Cmd+Shift+A)"