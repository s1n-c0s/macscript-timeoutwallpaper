# Screen Saver Guard

Automatically kill stuck `l-ScreenSaver` processes when you return.

## What It Does

When your screen saver gets stuck consuming CPU/Memory after you return, this script automatically detects and kills it within seconds.

**State Flow:**
```

WORKING (deep sleep) → IDLE (watching) → RETURNED (detected) → CHECK (kill if stuck) → WORKING

````

## Features

- ✅ **Zero impact when working** - Sleeps 30 minutes between checks
- ✅ **Instant detection** - Detects return within 5 seconds
- ✅ **Kills all instances** - Handles multiple stuck processes
- ✅ **Smart checking** - Only checks when you return (not during screen saver)
- ✅ **Dual threshold** - Kills if CPU > 1% **OR** Memory > 3MB
- ✅ **Native notifications** - macOS notifications with sounds
- ✅ **Graceful kill** - Tries SIGTERM first, then SIGKILL if needed
- ✅ **Auto-start** - Runs automatically on login

## Requirements

- macOS 10.14+
- No additional software required

## Installation

### 1. Create the Script

Copy this to `~/smart_screensaver_guard.sh`:

Make it executable:
\`\`\`bash
chmod +x ~/smart_screensaver_guard.sh
\`\`\`

### 2. Create LaunchAgent

Create `~/Library/LaunchAgents/com.smart.screensaver.plist`:

**Replace `YOUR_USERNAME` with your actual Mac username.**

### 3. Start the Service

\`\`\`bash
# Set permissions
chmod 644 ~/Library/LaunchAgents/com.smart.screensaver.plist

# Start now and enable auto-start on login
launchctl load ~/Library/LaunchAgents/com.smart.screensaver.plist
\`\`\`

## Configuration

Edit these values at the top of the script:

| Variable | Default | Description |
|----------|---------|-------------|
| `CPU_THRESHOLD` | `1` | Kill if CPU usage > 1% |
| `MEM_THRESHOLD_MB` | `3` | Kill if Memory usage > 3MB |
| `STATE` | `"WORKING"` | Initial state |

**To add Slack/Custom notifications**, modify the `notify()` function.

## How It Works

### State Machine

1. **WORKING** (30 min sleep)
   - You are actively using your Mac
   - Deep sleep to save CPU/battery
   - Checks every 30 minutes if you've gone idle

2. **IDLE** (5 sec sleep)
   - You stepped away (idle ≥ 5 seconds)
   - Screen saver potentially running
   - Waiting for you to return

3. **RETURNED** (instant)
   - You moved mouse/typed (idle < 5 sec after being idle)
   - Sends notification: "User Active"

4. **CHECK** (instant)
   - Scans all `legacyScreenSaver` processes
   - Kills any using CPU > 1% **OR** Memory > 3MB
   - Sends notifications per kill and summary

5. **Back to WORKING**

### Why This Approach?

- **No checking during work** - Zero CPU impact while you work
- **No checking during screen saver** - Only checks when you return (moment of truth)
- **Immediate kill** - No grace period, kills instantly if stuck
- **Kill all** - Finds and kills every stuck instance, not just first

## Verification

Check if it's running:
\`\`\`bash
launchctl list | grep com.smart.screensaver
# Should show: [PID] 0 com.smart.screensaver
\`\`\`

View logs:
\`\`\`bash
tail -f ~/Library/Logs/screensaver_smart.log
\`\`\`

Test notification:
\`\`\`bash
osascript -e 'display notification "Test" with title "Screen Saver Guard"'
\`\`\`

## Troubleshooting

### Not receiving notifications?
Go to **System Settings → Notifications → Script Editor** and enable "Allow Notifications"

### "Load failed: 5" error?
```bash
launchctl remove com.smart.screensaver
launchctl load ~/Library/LaunchAgents/com.smart.screensaver.plist
````

### Status 126 (permission denied)?

```bash
chmod +x ~/smart_screensaver_guard.sh
```

### Check current state:

```bash
tail -20 ~/Library/Logs/screensaver_smart.log
```

## Uninstall

```bash
# Stop service
launchctl unload ~/Library/LaunchAgents/com.smart.screensaver.plist

# Remove files
rm ~/Library/LaunchAgents/com.smart.screensaver.plist
rm ~/smart_screensaver_guard.sh
rm ~/Library/Logs/screensaver_smart.log

# Remove temp files
rm -f /tmp/smart_screensaver_guard.lock
```

## License

MIT - Free to use and modify.

