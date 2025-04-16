#!/usr/bin/env bash

# --- UTF-8 Locale Setup (Cross-Platform) ---
# Try known good locales on macOS and Linux
if locale -a 2>/dev/null | grep -q '^en_US.UTF-8$'; then
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
elif locale -a 2>/dev/null | grep -q '^C.UTF-8$'; then
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    export LC_CTYPE=C.UTF-8
else
    echo "Warning: No suitable UTF-8 locale found. UTF-8 handling may be broken." >&2
fi

# --- Source Engine Components ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

source "./config.sh"
source "./engine/logging.sh"
source "./engine/input.sh"
source "./engine/rendering.sh"
source "./engine/lifecycle.sh"

# --- Initialize and Run ---
> "$LOG_FILE"  # Clear log file on startup

setup_trap     # Register signal handlers and cleanup hooks
main           # Run application main loop
exit 0         # Ensure clean exit

