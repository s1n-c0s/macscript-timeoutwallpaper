#!/bin/bash

# Configuration
cd "$(dirname "$0")"
APP_NAME="SmartScreensaverGuard"
SCRIPT_NAME="smart_screensaver_guard.sh"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
PLIST_NAME="com.user.smartscreensaverguard.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "🚀 Installing $APP_NAME..."

# 1. Create directory
mkdir -p "$INSTALL_DIR"

# 2. Copy script
if [[ -f "$SCRIPT_NAME" ]]; then
    cp "$SCRIPT_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    echo "✅ Script copied to $INSTALL_DIR"
else
    echo "❌ Error: $SCRIPT_NAME not found in current directory."
    exit 1
fi

# 3. Create LaunchAgent Plist
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.smartscreensaverguard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$INSTALL_DIR/$SCRIPT_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/screensaver_smart.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/screensaver_smart.log</string>
</dict>
</plist>
EOF

echo "✅ LaunchAgent created at $PLIST_PATH"

# 4. Load the LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✨ Installation complete! $APP_NAME is now running in the background."
echo "You can check the logs at: ~/Library/Logs/screensaver_smart.log"
