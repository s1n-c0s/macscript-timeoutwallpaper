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
IDLE_START_TIME=0

# STARTUP notification
log "Started"
notify "🖥️ Screen Saver Guard" "Monitoring started" "Hero"

while :; do
    IDLE_SEC=$(get_idle)
    CURRENT_TIME=$(date +%s)
    
    case "$STATE" in
        
        "WORKING")
            if (( IDLE_SEC >= 5 )); then
                STATE="IDLE"
                IDLE_START_TIME=$CURRENT_TIME
                log "State: WORKING → IDLE"
                # IDLE notification - screensaver starting
                notify "💤 Screensaver" "Started monitoring (idle ${IDLE_SEC}s)" "Submarine"
            else
                sleep 300  # 5 min deep sleep
            fi
            ;;
            
        "IDLE")
            if (( IDLE_SEC < 5 )) && (( LAST_IDLE >= 5 )); then
                STATE="RETURNED"
                log "State: IDLE → RETURNED"
                continue
            fi
            
            # Safety timeout after 2 hours idle
            if (( CURRENT_TIME - IDLE_START_TIME > 7200 )); then
                log "Idle timeout, returning to WORKING"
                STATE="WORKING"
                LAST_IDLE=0
                continue
            fi
            
            LAST_IDLE=$IDLE_SEC
            sleep 5
            ;;
            
        "RETURNED")
            log "User returned from screensaver"
            # NO "User Active" notification here - only notify if killing
            
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
                    
                    if (( KILL_COUNT == 1 )); then
                        notify "👤 User Returned" "Screensaver stuck - killing..." "Basso"
                    fi
                    
                    log "KILL: legacyScreenSaver (PID:$PID, CPU:${CPU_INT}%, MEM:${RSS_MB}MB)"
                    notify "🛡️ Terminating" "legacyScreenSaver ${CPU_INT}%/${RSS_MB}MB" "Sosumi"
                    
                    if kill -15 "$PID" 2>/dev/null; then
                        sleep 2
                        if kill -0 "$PID" 2>/dev/null; then
                            kill -9 "$PID" 2>/dev/null
                            notify "⚡ Force Kill" "legacyScreenSaver killed" "Sosumi"
                        else
                            notify "✅ Success" "legacyScreenSaver exited cleanly" "Purr"
                        fi
                    fi
                fi
            done < <(ps aux | grep -i "[l]egacyScreenSaver" | grep -v grep)
            
            if (( KILL_COUNT == 0 )); then
                log "Screensaver exited normally"
            else
                log "Killed $KILL_COUNT process(es)"
            fi
            
            STATE="WORKING"
            log "State: RETURNED → WORKING"
            LAST_IDLE=0
            sleep 2
            ;;
            
    esac
done