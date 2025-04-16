# Engine Logging & Cleanup Utilities

# --- Logging Function ---
# Appends a timestamped message to the event log file.
# Usage: log_event "Your message here"
log_event() {
    local message="$1"
    # Use EVENT_LOG_FILE defined in engine_config_state.sh
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

# --- Cleanup Function ---
# Called by the trap on exit to restore terminal state.
cleanup() {
    log_event "Engine exiting"
    tput cnorm # Ensure cursor is visible
    clear      # Clear the screen
    # Any other cleanup tasks can go here
}

# --- Trap for Cleanup on Exit ---
# Sets up the cleanup function to run on script exit (normal or signal)
setup_trap() {
    # EXIT trap catches normal exits and signals like INT, TERM
    trap cleanup EXIT INT TERM
    log_event "Exit trap set up"
}

