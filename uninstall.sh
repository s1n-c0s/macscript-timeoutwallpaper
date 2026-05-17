#!/bin/bash

# Configuration
APP_NAME="SmartScreensaverGuard"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
PLIST_NAME="com.user.smartscreensaverguard.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "🗑️ Uninstalling $APP_NAME..."

# 1. Unload LaunchAgent
if [[ -f "$PLIST_PATH" ]]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null
    rm "$PLIST_PATH"
    echo "✅ LaunchAgent removed."
else
    echo "ℹ️ LaunchAgent not found."
fi

# 2. Remove Installation Directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "✅ Application files removed."
else
    echo "ℹ️ Installation directory not found."
fi

echo "✨ Uninstallation complete."
