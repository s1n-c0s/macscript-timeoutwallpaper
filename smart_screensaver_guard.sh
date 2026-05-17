#!/bin/bash

# Configuration
readonly CPU_THRESHOLD=1
readonly MEM_THRESHOLD_MB=3
readonly LOG_FILE="$HOME/Library/Logs/screensaver_smart.log"
readonly LOCK_FILE="/tmp/smart_screensaver_guard.lock"

# Single-instance guard
if [[ -f "$LOCK_FILE" ]] && kill -0 "$(<"$LOCK_FILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# Utilities
notify() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"$3\"" &>/dev/null &
}

log() {
    printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >> "$LOG_FILE"
}

get_idle_time() {
    # Returns idle time in seconds
    ioreg -c IOHIDSystem -r 2>/dev/null | awk '/HIDIdleTime/{gsub(/[^0-9]/,"",$NF); print int($NF/1e9); exit}'
}

kill_stuck_screensaver() {
    local count=0 pid cpu rss
    # Use process substitution to avoid subshell variable loss
    while read -r pid cpu rss; do
        [[ -z "$pid" ]] && continue
        cpu=${cpu%.*}
        rss=$((rss/1024))
        
        if (( cpu > CPU_THRESHOLD || rss > MEM_THRESHOLD_MB )); then
            ((count++)) || notify "👤 User Returned" "Screensaver stuck - killing..." "Basso"
            
            log "KILL: legacyScreenSaver (PID:$pid, CPU:${cpu}%, MEM:${rss}MB)"
            notify "🛡️ Terminating" "legacyScreenSaver ${cpu}%/${rss}MB" "Sosumi"
            
            if kill -15 "$pid" 2>/dev/null; then
                sleep 2
                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null
                    notify "⚡ Force Kill" "legacyScreenSaver killed" "Sosumi"
                else
                    notify "✅ Success" "legacyScreenSaver exited cleanly" "Purr"
                fi
            fi
        fi
    done < <(ps aux | awk '/[l]egacyScreenSaver/{print $2,$3,$6}')
    
    if (( count > 0 )); then
        log "Killed $count process(es)"
    else
        log "Screensaver exited normally"
    fi
}

# Main Execution
log "Monitoring started"
notify "🖥️ Screen Saver Guard" "Monitoring started" "Hero"

idle_start_time=0

while :; do
    current_idle=$(get_idle_time)
    current_time=$(date +%s)
    
    if (( current_idle < 5 )); then
        # User is active
        if (( idle_start_time > 0 )); then
            # Just returned from idle
            kill_stuck_screensaver
            idle_start_time=0
            sleep 2
        else
            # Keep sleeping while user is active (low frequency check)
            sleep 300
        fi
    else
        # User is idle
        if (( idle_start_time == 0 )); then
            idle_start_time=$current_time
            log "State: WORKING → IDLE"
        fi
        
        # Safety timeout after 2 hours of idle (reset tracking)
        if (( current_time - idle_start_time > 7200 )); then
            log "Idle timeout (2h), resetting tracking"
            idle_start_time=0
        fi
        
        # High frequency check while idle
        sleep 5
    fi
done
