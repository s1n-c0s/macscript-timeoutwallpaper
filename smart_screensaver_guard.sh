#!/bin/bash

IDLE_THRESHOLD_SEC=5      # Detect return after 5 seconds of activity
CPU_THRESHOLD=1           # Kill if using >1% CPU  
GRACE_CHECKS=2            # Check twice quickly after return
LOG_FILE="$HOME/Library/Logs/screensaver_smart.log"
LOCK_FILE="/tmp/smart_screensaver_guard.lock"

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if ps -p "$OLD_PID" -o comm= 2>/dev/null | grep -q bash; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' INT TERM EXIT

notify() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"$3\"" 2>/dev/null &
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

get_idle_seconds() {
    local idle_nanos=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF; exit}')
    if [[ "$idle_nanos" == 0x* ]]; then
        printf "%d" "$idle_nanos" | awk '{print int($1/1000000000)}'
    else
        echo "$((idle_nanos / 1000000000))"
    fi
}

log "Started (Kill on return if stuck)"
notify "🖥️ Screen Saver Guard" "Active - Will kill stuck savers on return" "Hero"

WAS_IDLE=0
CHECK_COUNT=0

while true; do
    IDLE_SEC=$(get_idle_seconds)
    
    # USER IS IDLE - Screen saver running normally, just wait
    if [ "$IDLE_SEC" -ge "$IDLE_THRESHOLD_SEC" ]; then
        if [ "$WAS_IDLE" -eq 0 ]; then
            log "User went idle (${IDLE_SEC}s), screen saver starting..."
            WAS_IDLE=1
            CHECK_COUNT=0
        fi
        sleep 5
        continue
    fi
    
    # USER JUST RETURNED (was idle, now active)
    if [ "$WAS_IDLE" -eq 1 ]; then
        log "User returned! Checking for stuck screen saver..."
        notify "👤 User Active" "Checking screen saver status..." "Pop"
        WAS_IDLE=0
        CHECK_COUNT=0
        
        # Check immediately and for next 60 seconds (in case it exits slowly)
        while [ "$CHECK_COUNT" -lt "$GRACE_CHECKS" ]; do
            # Find all legacyScreenSaver processes
            ps aux | grep -i "[l]egacyScreenSaver" | while IFS= read -r line; do
                [ -z "$line" ] && continue
                
                PID=$(echo "$line" | awk '{print $2}')
                CPU=$(echo "$line" | awk '{print $3}')
                CPU_INT=${CPU%.*}
                [ -z "$CPU_INT" ] && CPU_INT=0
                
                if [[ "$line" == *"System Settings"* ]]; then
                    TYPE="System Settings"
                else
                    TYPE="Wallpaper"
                fi
                
                # If still running with high CPU after user returned, it's STUCK
                if [ "$CPU_INT" -gt "$CPU_THRESHOLD" ]; then
                    log "STUCK DETECTED: $TYPE | PID $PID | CPU ${CPU_INT}% | Check $((CHECK_COUNT+1))/${GRACE_CHECKS}"
                    
                    if [ "$CHECK_COUNT" -eq 0 ]; then
                        notify "⚠️ Stuck Screen Saver" "$TYPE still running (${CPU_INT}%) - Killing..." "Basso"
                    fi
                    
                    # Kill immediately on first detection or wait for grace
                    if [ "$CHECK_COUNT" -ge "$((GRACE_CHECKS-1))" ]; then
                        log "KILLING stuck $TYPE (PID $PID)"
                        notify "🛡️ Terminating" "Killing stuck $TYPE" "Sosumi"
                        
                        kill -15 "$PID" 2>/dev/null
                        sleep 2
                        
                        if ps -p "$PID" > /dev/null 2>&1; then
                            kill -9 "$PID" 2>/dev/null
                            log "Force killed $TYPE"
                            notify "⚡ Force Kill" "$TYPE required SIGKILL" "Sosumi"
                        else
                            log "Graceful kill $TYPE"
                            notify "✅ Killed" "$TYPE exited cleanly" "Purr"
                        fi
                    fi
                else
                    # CPU low, probably exiting normally
                    log "$TYPE CPU low (${CPU_INT}%), ignoring"
                fi
            done
            
            CHECK_COUNT=$((CHECK_COUNT+1))
            if [ "$CHECK_COUNT" -lt "$GRACE_CHECKS" ]; then
                sleep 10  # Wait 10s between checks
            fi
        done
        
        log "Check complete, resuming monitor"
    fi
    
    # User active, screen saver not running (normal state)
    sleep 5
done