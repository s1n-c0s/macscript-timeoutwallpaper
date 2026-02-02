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

log "Started - Kill ALL legacyScreenSaver"
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
            
            # Find and kill ALL legacyScreenSaver processes
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                
                PID=$(echo "$line" | awk '{print $2}')
                CPU=$(echo "$line" | awk '{print $3}')
                RSS=$(echo "$line" | awk '{print $6}')
                
                CPU_INT=${CPU%.*}
                [[ -z "$CPU_INT" ]] && CPU_INT=0
                RSS_MB=$((RSS / 1024))
                
                # Kill if CPU > 1% OR MEM > 3MB
                if [[ "$CPU_INT" -gt "$CPU_THRESHOLD" ]] || [[ "$RSS_MB" -gt "$MEM_THRESHOLD_MB" ]]; then
                    ((KILL_COUNT++))
                    
                    log "KILL #$KILL_COUNT: legacyScreenSaver (PID:$PID, CPU:${CPU_INT}%, MEM:${RSS_MB}MB)"
                    
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
                log "Killed $KILL_COUNT legacyScreenSaver process(es)"
                notify "🛡️ Complete" "Killed $KILL_COUNT process(es)" "Hero"
            else
                log "All clear"
            fi
            
            STATE="WORKING"
            log "State: CHECK → WORKING"
            LAST_IDLE=0
            ;;
            
    esac
done