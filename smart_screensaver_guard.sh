#!/bin/bash

readonly CPU_THRESHOLD=1
readonly MEM_THRESHOLD_MB=3
readonly LOG_FILE="$HOME/Library/Logs/screensaver_smart.log"
readonly LOCK_FILE="/tmp/smart_screensaver_guard.lock"

# Single-instance guard
[[ -f "$LOCK_FILE" ]] && kill -0 "$(<"$LOCK_FILE")" 2>/dev/null && exit
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# Utilities
notify() { osascript -e "display notification \"$2\" with title \"$1\" sound name \"$3\"" &>/dev/null & }
log() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >> "$LOG_FILE"; }
idle_time() { ioreg -c IOHIDSystem -r 2>/dev/null | awk '/HIDIdleTime/{print int($NF/1000000000)}'; }

# Actions
kill_screensaver() {
    local count=0 pid cpu rss
    while read -r pid cpu rss; do
        [[ -z "$pid" ]] && continue
        rss=$((rss/1024)); cpu=${cpu%.*}
        (( cpu > CPU_THRESHOLD || rss > MEM_THRESHOLD_MB )) || continue
        
        ((count++)) || notify "👤 User Returned" "Screensaver stuck - killing..." "Basso"
        log "KILL: legacyScreenSaver (PID:$pid, CPU:${cpu}%, MEM:${rss}MB)"
        notify "🛡️ Terminating" "legacyScreenSaver ${cpu}%/${rss}MB" "Sosumi"
        
        if kill -15 "$pid" 2>/dev/null; then
            sleep 2
            { kill -0 "$pid" 2>/dev/null && kill -9 "$pid" && notify "⚡ Force Kill" "legacyScreenSaver killed" "Sosumi"; } ||
            notify "✅ Success" "legacyScreenSaver exited cleanly" "Purr"
        fi
    done < <(ps aux | awk '/[l]egacyScreenSaver/{print $2,$3,$6}')
    (( count )) && log "Killed $count process(es)" || log "Screensaver exited normally"
}

# Main loop
log "Started"
notify "🖥️ Screen Saver Guard" "Monitoring started" "Hero"

idle_start=0
while :; do
    idle=$(idle_time)
    now=$(date +%s)
    
    if (( idle < 5 )); then
        # Active
        if (( idle_start )); then
            kill_screensaver
            idle_start=0
            sleep 2
        else
            sleep 300  # Deep sleep while working
        fi
        
    else
        # Idle
        (( idle_start )) || { idle_start=$now; log "State: WORKING → IDLE"; }
        (( now - idle_start > 7200 )) && { log "Idle timeout"; idle_start=0; }  # 2h safety
        sleep 5
    fi
done
