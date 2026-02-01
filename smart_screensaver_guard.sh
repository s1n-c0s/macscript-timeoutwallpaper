#!/bin/bash

IDLE_THRESHOLD_SEC=5
CPU_THRESHOLD=1
GRACE_CHECKS=2
LOG_FILE="$HOME/Library/Logs/screensaver_smart.log"
LOCK_FILE="/tmp/smart_screensaver_guard.lock"
STATE_FILE="/tmp/screensaver_state"

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if ps -p "$OLD_PID" -o comm= 2>/dev/null | grep -q bash; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
echo "WORKING" > "$STATE_FILE"
trap 'rm -f "$LOCK_FILE" "$STATE_FILE"' INT TERM EXIT

notify() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"$3\"" 2>/dev/null &
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# Optimized idle check
get_idle_seconds() {
    ioreg -c IOHIDSystem -r 2>/dev/null | \
    awk '/HIDIdleTime/ { gsub(/[^0-9]/,"",$NF); print int($NF/1000000000); exit }'
}

log "Started (Optimized)"
notify "🖥️ Screen Saver Guard" "Active - Deep sleep mode" "Hero"

while true; do
    IDLE_SEC=$(get_idle_seconds)
    CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "WORKING")
    
    # STATE 1: Working (not idle) - DEEP SLEEP
    if [ "$IDLE_SEC" -lt "$IDLE_THRESHOLD_SEC" ]; then
        if [ "$CURRENT_STATE" == "IDLE" ]; then
            # TRANSITION: Just returned!
            log "User returned - checking..."
            notify "👤 User Active" "Checking for stuck processes..." "Pop"
            
            CHECK_COUNT=0
            NOTIFIED=0
            
            # Check loop with process substitution (no subshell bug)
            while [ "$CHECK_COUNT" -lt "$GRACE_CHECKS" ]; do
                FOUND=0
                
                # Optimized: Use process substitution instead of pipe
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    
                    PID=$(echo "$line" | awk '{print $2}')
                    CPU=$(echo "$line" | awk '{print $3}')
                    CPU_INT=${CPU%.*}
                    [ -z "$CPU_INT" ] && CPU_INT=0
                    
                    [[ "$line" == *"System Settings"* ]] && TYPE="System Settings" || TYPE="Wallpaper"
                    
                    if [ "$CPU_INT" -gt "$CPU_THRESHOLD" ]; then
                        FOUND=1
                        
                        # Notify only once
                        if [ "$NOTIFIED" -eq 0 ]; then
                            log "STUCK: $TYPE (PID:$PID CPU:${CPU_INT}%)"
                            notify "⚠️ Stuck Detected" "$TYPE using ${CPU_INT}%" "Basso"
                            NOTIFIED=1
                        fi
                        
                        # Kill on final check
                        if [ "$CHECK_COUNT" -ge "$((GRACE_CHECKS-1))" ]; then
                            log "KILLING $TYPE"
                            notify "🛡️ Terminating" "Killing $TYPE" "Sosumi"
                            
                            kill -15 "$PID" 2>/dev/null && sleep 2
                            if ps -p "$PID" >/dev/null 2>&1; then
                                kill -9 "$PID" 2>/dev/null
                                notify "⚡ Force Kill" "$TYPE killed" "Sosumi"
                            else
                                notify "✅ Success" "$TYPE exited cleanly" "Purr"
                            fi
                        fi
                    else
                        log "$TYPE CPU normal (${CPU_INT}%)"
                    fi
                done < <(ps aux | grep -i "[l]egacyScreenSaver")
                
                [ "$FOUND" -eq 0 ] && break  # Exit early if nothing found
                
                CHECK_COUNT=$((CHECK_COUNT+1))
                [ "$CHECK_COUNT" -lt "$GRACE_CHECKS" ] && sleep 10
            done
            
            [ "$NOTIFIED" -eq 0 ] && log "No stuck processes"
            echo "WORKING" > "$STATE_FILE"
        fi
        
        # DEEP SLEEP: 30 minutes (practically zero CPU)
        sleep 3600
        continue
    fi
    
    # STATE 2: Idle - Light sleep waiting for return
    if [ "$CURRENT_STATE" == "WORKING" ]; then
        log "User went idle"
        echo "IDLE" > "$STATE_FILE"
    fi
    
    # Progressive sleep: 5s → 10s → 30s to save power while idle
    # Fast detection in first minute, then slow down
    CYCLE=$(cat /tmp/screensaver_cycle 2>/dev/null || echo 0)
    
    if [ "$CYCLE" -lt 12 ]; then      # First 60s: check every 5s
        sleep 5
        echo $((CYCLE+1)) > /tmp/screensaver_cycle
    elif [ "$CYCLE" -lt 18 ]; then    # Next 60s: check every 10s
        sleep 10
        echo $((CYCLE+1)) > /tmp/screensaver_cycle
    else                              # After 2min: check every 30s
        sleep 30
    fi
done

