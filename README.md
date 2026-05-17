# Screen Saver Guard

Automatically kill stuck `l-ScreenSaver` processes when you return.

## What It Does

When your screen saver gets stuck consuming CPU/Memory after you return, this script automatically detects and kills it within seconds.

**State Flow:**
```

WORKING (deep sleep) → IDLE (watching) → RETURNED (detected) → CHECK (kill if stuck) → WORKING

```

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

### 1. Easy Setup (GUI)

Simply **double-click** the `Setup.command` file in the folder. This opens a single-screen control panel where you can:

- **🔍 Check Status**: Instantly see if the background service is running.
- **🛠 Check Access**: Guides you through granting the necessary **Accessibility** permissions.
- **🚀 Install Service**: Sets up the guard to run automatically in the background.
- **🗑 Uninstall Service**: Completely removes the service and associated files.

### 2. Manual Verification

If you prefer using the Terminal, you can check the status with:
```bash
launchctl list | grep com.user.smartscreensaverguard
```

View real-time activity logs:
```bash
tail -f ~/Library/Logs/screensaver_smart.log
```

## Configuration

Edit these values at the top of the script:

| Variable | Default | Description |
|----------|---------|-------------|
| `CPU_THRESHOLD` | `1` | Kill if CPU usage > 1% |
| `MEM_THRESHOLD_MB` | `3` | Kill if Memory usage > 3MB |

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

## Troubleshooting

### Not receiving notifications?
Go to **System Settings → Notifications → Script Editor** and enable "Allow Notifications"

### Check current state:
```bash
tail -20 ~/Library/Logs/screensaver_smart.log
```

## License

MIT - Free to use and modify.
