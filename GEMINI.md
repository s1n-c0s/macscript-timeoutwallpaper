# GEMINI.md - Project Context & Instructions

## Project Overview
**Smart Screensaver Guard** is a macOS-native utility designed to automatically detect and terminate stuck `legacyScreenSaver` processes. These processes often fail to exit cleanly when a user returns from idle, leading to high CPU and memory consumption.

- **Primary Language:** Bash (macOS compatible)
- **Target OS:** macOS 10.14+
- **Architecture:** State-machine based monitoring daemon.

## Architecture & Logic
The monitoring script (`smart_screensaver_guard.sh`) operates as a background process with the following state logic:

1.  **WORKING (Active):** The user is active. The script sleeps for 300 seconds (5 minutes) between checks to minimize system impact.
2.  **IDLE (Monitoring):** Detected when `HIDIdleTime` ≥ 5 seconds. The script switches to high-frequency polling (every 5 seconds) to wait for the user's return.
3.  **RETURNED (Action):** Detected when `HIDIdleTime` drops below 5 seconds after an idle period. The script scans for `legacyScreenSaver` processes and kills them if:
    - CPU usage > 1%
    - OR Memory usage > 3MB
4.  **Notifications:** Uses `osascript` to provide native macOS notifications for startup, process termination, and force-kill events.

## Key Files
- `smart_screensaver_guard.sh`: The core monitoring logic (fixed date formatting for logging).
- `Setup.command`: A unified, single-screen GUI (AppleScript) for managing the service.
- `install.sh`: Backend installer script.
- `uninstall.sh`: Backend uninstaller script.
- `README.md`: User-facing documentation.

## Installation & Management
### GUI Management
The primary way to manage the service is via **`Setup.command`**, which provides a single-screen interface that **automatically shows the current status** (Running/Stopped) and allows for:
- **Managing Permissions**: Guides the user through granting Accessibility access.
- **Installing/Uninstalling**: Automates the setup and teardown of the background daemon.

### Manual Control
- **Start/Stop:** Managed via `launchctl` using the plist at `~/Library/LaunchAgents/com.user.smartscreensaverguard.plist`.
- **Logs:** Monitoring logs are stored at `~/Library/Logs/screensaver_smart.log`.
- **Lock File:** Prevents multiple instances via `/tmp/smart_screensaver_guard.lock`.

## Development Conventions
- **Version Control:** Versions are managed via Git branches (`v1`, `v2`, etc.). The `main` branch always contains the latest stable and optimized version.
- **Portability:** Use standard macOS CLI tools (`ioreg`, `ps`, `awk`, `osascript`, `launchctl`). Avoid external dependencies.
- **Robustness:** Use process substitution `< <(...)` when reading process lists to avoid subshell variable loss.
- **Safety:** Always try `SIGTERM` (-15) before `SIGKILL` (-9).

## Future Improvements (TODO)
- Add support for custom notification hooks (e.g., Slack, Webhooks).
- Implement configurable thresholds via a config file instead of hardcoded variables.
- Add a "dry-run" mode for testing detection logic without killing processes.
