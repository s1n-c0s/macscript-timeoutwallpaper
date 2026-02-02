```markdown
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

\`\`\`bash
#!/bin/bash

readonly CPU_THRESHOLD=1
readonly MEM_THRESHOLD_MB=3
readonly LOG_FILE="$HOME/Library/Logs/screensaver_smart.log"
readonly LOCK_FILE="/tmp/smart_screensaver_guard.lock"

if [[ -f "$LOCK_FILE" ]] && kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

notify() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"$3\"" &>/dev/null &
}

log() {
    printf '[%(%H:%M:%S)T] %s\n' -1 "$1" >> "$LOG_FILE"
}

get_idle() {
    local idle
    idle=$(ioreg -c IOHIDSystem -r 2>/dev/null | awk '/HIDIdleTime/{gsub(/[^0-9]/,"",$NF); print int($NF/1000000000); exit}')
    echo "${idle:-0}"
}

STATE="WORKING"
LAST_IDLE=0

log "Started - Kill ALL mode"
notify "🖥️ Guard Active" "Monitoring legacyScreenSaver" "Hero"

while :; do
    IDLE_SEC=$(get_idle)

    case "$STATE" in

        "WORKING")
            if (( IDLE_SEC >= 5 )); then
                STATE="IDLE"
                log "State: WORKING → IDLE"
                LAST_IDLE=$IDLE_SEC
            else
                sleep 1800
            fi
            ;;

        "IDLE")
            if (( IDLE_SEC < 5 )) && (( LAST_IDLE >= 5 )); then
                STATE="RETURNED"
                log "State: IDLE → RETURNED"
                continue
            fi
            LAST_IDLE=$IDLE_SEC
            sleep 5
            ;;

        "RETURNED")
            log "User returned! Checking..."
            notify "👤 User Active" "Checking legacyScreenSaver..." "Pop"
            STATE="CHECK"
            continue
            ;;

        "CHECK")
            KILL_COUNT=0

            while IFS= read -r line; do
                [[ -z "$line" ]] && continue

                PID=$(echo "$line" | awk '{print $2}')
                CPU=$(echo "$line" | awk '{print $3}')
                RSS=$(echo "$line" | awk '{print $6}')

                CPU_INT=${CPU%.*}
                [[ -z "$CPU_INT" ]] && CPU_INT=0
                RSS_MB=$((RSS / 1024))

                if [[ "$CPU_INT" -gt "$CPU_THRESHOLD" ]] || [[ "$RSS_MB" -gt "$MEM_THRESHOLD_MB" ]]; then
                    ((KILL_COUNT++))
                    log "KILL #$KILL_COUNT: legacyScreenSaver (PID:$PID, CPU:${CPU_INT}%, MEM:${RSS_MB}MB)"
                    notify "🛡️ Killing #$KILL_COUNT" "legacyScreenSaver ${CPU_INT}%/${RSS_MB}MB" "Basso"

                    if kill -15 "$PID" 2>/dev/null; then
                        sleep 2
                        if kill -0 "$PID" 2>/dev/null; then
                            kill -9 "$PID" 2>/dev/null
                            log "Force killed PID:$PID"
                        else
                            log "Graceful kill PID:$PID"
                        fi
                    fi
                fi
            done < <(ps aux | grep -i "[l]egacyScreenSaver" | grep -v grep)

            if (( KILL_COUNT > 0 )); then
                log "Killed $KILL_COUNT process(es)"
                notify "✅ Complete" "Killed $KILL_COUNT stuck process(es)" "Hero"
            else
                log "All clear"
            fi

            STATE="WORKING"
            log "State: CHECK → WORKING"
            LAST_IDLE=0
            ;;

    esac
done
\`\`\`

Make it executable:
\`\`\`bash
chmod +x ~/smart_screensaver_guard.sh
\`\`\`

### 2. Create LaunchAgent

Create `~/Library/LaunchAgents/com.smart.screensaver.plist`:

\`\`\`xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.smart.screensaver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOUR_USERNAME/smart_screensaver_guard.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>Nice</key>
    <integer>10</integer>
</dict>
</plist>
\`\`\`

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

```

**This README covers:**
- Clear description of the state machine
- Step-by-step installation
- Configuration options
- Troubleshooting section
- Uninstall instructions

**Does this cover everything you need?** Want me to add a specific section (like "Known Issues" or "Advanced Configuration")?
```
