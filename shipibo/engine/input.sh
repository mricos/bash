# Engine Input Handling

# --- Input Action Functions ---
action_quit() { log_event "Quit action triggered."; SHOULD_EXIT=1; }
action_toggle_run() { RUNNING=$((1-RUNNING)); if [[ $RUNNING -eq 1 ]]; then STATUS_MESSAGE="Running..."; else STATUS_MESSAGE="Paused"; fi; log_event "Toggled running state to $RUNNING"; }
action_toggle_fullscreen() { FULL_SCREEN=$((1-FULL_SCREEN)); STATUS_MESSAGE="Full screen mode: $([[ $FULL_SCREEN -eq 1 ]] && echo "ON" || echo "OFF")"; log_event "Toggled full screen mode to $FULL_SCREEN"; }
action_toggle_empty_view() { EMPTY_DISPLAY=$((1-EMPTY_DISPLAY)); STATUS_MESSAGE="Empty view mode: $([[ $EMPTY_DISPLAY -eq 1 ]] && echo "ON" || echo "OFF")"; log_event "Toggled empty view mode to $EMPTY_DISPLAY"; }
action_step() {
    if [[ $RUNNING -eq 1 ]]; then STATUS_MESSAGE="Pause (SPACE) before stepping (c)"; return; fi
    if declare -F update_algorithm &>/dev/null; then
        log_event "Manual step requested for ${ALGO_FILE}"
        update_algorithm; local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then RUNNING=0; log_event "Manual step finished for ${ALGO_FILE}, algorithm signaled stop (code $exit_code)";
        else log_event "Manual step finished for ${ALGO_FILE} (code $exit_code)"; fi
    else STATUS_MESSAGE="Error: update_algorithm not found in ${ALGO_FILE}"; echo "ERROR: update_algorithm not found (manual step)" >&2; fi
}
action_next_algo() {
    local total_algos=${#ALGO_FILES[@]}; if [[ $total_algos -gt 0 ]]; then
        local next_index=$(( (CURRENT_ALGO_INDEX + 1) % total_algos ))
        if [[ "$next_index" -ne "$CURRENT_ALGO_INDEX" ]]; then load_and_init_algorithm "$next_index"; fi
    fi
}
action_prev_algo() {
    local total_algos=${#ALGO_FILES[@]}; if [[ $total_algos -gt 0 ]]; then
        local prev_index=$(( (CURRENT_ALGO_INDEX - 1 + total_algos) % total_algos ))
         if [[ "$prev_index" -ne "$CURRENT_ALGO_INDEX" ]]; then load_and_init_algorithm "$prev_index"; fi
    fi
}
action_next_doc_page() {
     if [[ ${#PAGES[@]} -gt 0 ]]; then local old_page=$CURRENT_DOC_PAGE; CURRENT_DOC_PAGE=$(( (CURRENT_DOC_PAGE + 1) % ${#PAGES[@]} )); if [[ $old_page != $CURRENT_DOC_PAGE ]]; then STATUS_MESSAGE="Doc Page $((CURRENT_DOC_PAGE+1))/${#PAGES[@]}"; log_event "Changed to Doc Page $CURRENT_DOC_PAGE"; fi
    else STATUS_MESSAGE="No Doc Pages available"; fi
}
action_prev_doc_page() {
    if [[ ${#PAGES[@]} -gt 0 ]]; then local old_page=$CURRENT_DOC_PAGE; CURRENT_DOC_PAGE=$(( (CURRENT_DOC_PAGE - 1 + ${#PAGES[@]}) % ${#PAGES[@]} )); if [[ $old_page != $CURRENT_DOC_PAGE ]]; then STATUS_MESSAGE="Doc Page $((CURRENT_DOC_PAGE+1))/${#PAGES[@]}"; log_event "Changed to Doc Page $CURRENT_DOC_PAGE"; fi
    else STATUS_MESSAGE="No Doc Pages available"; fi
}
action_pass_to_algo() {
    local key_passed="$1"; if declare -F handle_input &>/dev/null; then log_event "Passing key '$key_passed' to algorithm ${ALGO_FILE}"; handle_input "$key_passed";
    else log_event "Key '$key_passed' pressed, but ${ALGO_FILE} has no handle_input function"; fi
}

# --- Keybinding Setup --- (Now handled in engine/lifecycle.sh by _load_control_definitions)
# REMOVED setup_keybindings function

# --- Input Processing ---

# Variable to control controls display (toggled by action_toggle_controls)
declare -g SHOW_CONTROLS=0 # Start with controls hidden


# Tries to read a keypress (including escape sequences) and returns a symbolic name.
# Returns:
#   0: Success, symbolic name printed to stdout
#   1: Timeout/Read error
# Symbolic Names: q, c, f, SPACE, UP, DOWN, LEFT, RIGHT, ESC, etc.
_get_key_symbol() {
    local char next_char final_char seq rest
    # Read the first character with a short timeout
    if ! read -sN1 -t 0.05 char; then
        return 1 # Timeout or read error
    fi

    case "$char" in
        $'\e') # ESC or start of sequence
            # Try reading the next characters non-blockingly
            if ! read -sN1 -t 0.01 next_char; then
                echo "ESC"; return 0 # Just ESC pressed
            fi
            if [[ "$next_char" == '[' ]]; then
                if ! read -sN1 -t 0.01 final_char; then
                   # Incomplete sequence (e.g., CSI followed by nothing quickly)
                   # Could potentially return "ESC" or handle differently
                   echo "ESC"; return 0 # Treat as ESC for now
                fi
                case "$final_char" in
                    A) echo "UP"; return 0 ;;
                    B) echo "DOWN"; return 0 ;;
                    C) echo "RIGHT"; return 0 ;;
                    D) echo "LEFT"; return 0 ;;
                    # Add other CSI sequences here if needed (Home, End, PgUp, PgDn, F-keys)
                    # Example: '1~' or 'H' for Home, '4~' or 'F' for End
                    # Example: '2~' for Insert, '3~' for Delete
                    # Example: '5~' for PgUp, '6~' for PgDn
                    # Example: P=F1, Q=F2, R=F3, S=F4 (might vary)
                    # Example: 15~=F5, 17~=F6, 18~=F7, 19~=F8, 20~=F9, 21~=F10, 23~=F11, 24~=F12
                    *) # Unrecognized CSI sequence, maybe read rest?
                       # Let's treat unrecognized sequences as ESC for now
                       read -sN5 -t 0.01 rest # Consume potential remaining chars
                       echo "ESC"; return 0 ;;
                esac
             elif [[ "$next_char" == 'O' ]]; then # SS3 sequences (used by some terminals for F1-F4)
                  if ! read -sN1 -t 0.01 final_char; then echo "ESC"; return 0; fi
                  case "$final_char" in
                      P) echo "F1"; return 0;; # Example
                      Q) echo "F2"; return 0;; # Example
                      R) echo "F3"; return 0;; # Example
                      S) echo "F4"; return 0;; # Example
                      *) echo "ESC"; return 0;; # Treat as ESC
                  esac
            else
                # ESC followed by something else (e.g., Alt+key?)
                # For now, just return ESC and the next char as separate events maybe?
                # Or treat as just ESC?
                 echo "ESC"; return 0 # Treat as ESC for now
            fi
            ;;
        ' ') # Space bar
            echo "SPACE"; return 0
            ;;
        # Add cases for other single chars needing symbolic names if any (e.g., ENTER, TAB)
        # $'\n') echo "ENTER"; return 0 ;; # Example for Enter key
        # $'\t') echo "TAB"; return 0 ;;   # Example for Tab key
        *) # Regular printable character (or control character like Ctrl+C)
           # TODO: Handle control characters (e.g. Ctrl+C -> CTRL_C)?
           # For now, return the character itself
           echo "$char"; return 0
           ;;
    esac

    return 1 # Should not be reached ideally
}

# Processes a single key press using the symbolic name.
# Reads input via _get_key_symbol, looks up action in KEY_ACTIONS, executes it.
# Returns 1 if a redraw is needed, 0 otherwise.
_process_input() {
    local key_symbol action_string
    if key_symbol=$(_get_key_symbol); then
        # Check if the key exists in our map
        if [[ -v KEY_ACTIONS[$key_symbol] ]]; then
            action_string="${KEY_ACTIONS[$key_symbol]}"
            log_event "Input: '$key_symbol' -> Action: '$action_string'"
            eval "$action_string" # Execute the action function
            return 1 # Assume any mapped key requires a redraw
        else
            log_event "Input: '$key_symbol' (unmapped)"
            # Optionally provide feedback for unmapped keys?
            # STATUS_MESSAGE="Key '$key_symbol' not bound"
            return 0 # Unmapped key doesn't necessarily require redraw
        fi
    fi
    # No key read (timeout from _get_key_symbol)
    return 0
}

# --- Action Stubs ---
# (Keep existing action stubs: action_toggle_controls, etc.)

# Ensure necessary action functions exist:
action_toggle_controls() {
    SHOW_CONTROLS=$((1 - SHOW_CONTROLS))
    log_event "ACTION: Toggled controls visibility to $SHOW_CONTROLS"
    return 1 # Signal redraw
}
action_cycle_format(){ log_warn "ACTION: action_cycle_format not fully implemented"; return 1; }
action_prev_mode(){ log_warn "ACTION: action_prev_mode not fully implemented"; return 1; }
action_next_mode(){ log_warn "ACTION: action_next_mode not fully implemented"; return 1; }
# Add stubs for other missing actions if needed

# --- New Render Mode Cycle Actions ---
_get_available_render_modes() {
    # TODO: Query glyph.sh or parse RENDER_MAP keys more robustly
    # Hardcoded for now based on typical glyphs.conf entries
    echo "ASCII UTF8_BASIC UTF8_COLOR EMOJI"
}

action_next_render_mode() {
    local -a modes_available=( $(_get_available_render_modes) )
    local current_index=-1
    for i in "${!modes_available[@]}"; do 
        if [[ "${modes_available[$i]}" == "$CURRENT_RENDER_MODE" ]]; then 
            current_index=$i; 
            break; 
        fi; 
    done
    if [[ $current_index -ne -1 && ${#modes_available[@]} -gt 1 ]]; then 
        local next_index=$(( (current_index + 1) % ${#modes_available[@]} ))
        CURRENT_RENDER_MODE="${modes_available[$next_index]}"
        STATUS_MESSAGE="Render Mode: $CURRENT_RENDER_MODE"
        log_event "Switched Render Mode to $CURRENT_RENDER_MODE"
        FORCE_FULL_REDRAW=1 # Mode change requires full redraw
    elif [[ ${#modes_available[@]} -le 1 ]]; then 
        STATUS_MESSAGE="Only one Render Mode available: $CURRENT_RENDER_MODE"
    fi
}

action_prev_render_mode() {
    local -a modes_available=( $(_get_available_render_modes) )
    local current_index=-1
    for i in "${!modes_available[@]}"; do 
        if [[ "${modes_available[$i]}" == "$CURRENT_RENDER_MODE" ]]; then 
            current_index=$i; 
            break; 
        fi; 
    done
    if [[ $current_index -ne -1 && ${#modes_available[@]} -gt 1 ]]; then 
        local prev_index=$(( (current_index - 1 + ${#modes_available[@]}) % ${#modes_available[@]} ))
        CURRENT_RENDER_MODE="${modes_available[$prev_index]}"
        STATUS_MESSAGE="Render Mode: $CURRENT_RENDER_MODE"
        log_event "Switched Render Mode to $CURRENT_RENDER_MODE"
        FORCE_FULL_REDRAW=1 # Mode change requires full redraw
    elif [[ ${#modes_available[@]} -le 1 ]]; then 
        STATUS_MESSAGE="Only one Render Mode available: $CURRENT_RENDER_MODE"
    fi
}

# --- Toggle Backtracking (Placeholder) ---
action_toggle_backtracking() {
    if [[ $ENABLE_BACKTRACKING -eq 0 ]]; then
        ENABLE_BACKTRACKING=1
        STATUS_MESSAGE="Backtracking Enabled (Note: Algorithm may not support it)"
        log_event "$STATUS_MESSAGE"
    else
        ENABLE_BACKTRACKING=0
        STATUS_MESSAGE="Backtracking Disabled"
        log_event "$STATUS_MESSAGE"
    fi
    return 0 # Doesn't require immediate redraw by itself
}

# --- Toggle Blocky Algorithm Rule Mode ---
action_toggle_blocky_mode() {
    # Only makes sense for blocky.sh
    if [[ "$ALGO_FILE" != "blocky.sh" ]]; then
        STATUS_MESSAGE="Rule mode toggle only affects blocky.sh"
        return 0 # No redraw needed
    fi

    # Cycle through modes 0, 1, 2
    local current_mode=${BLOCKY_RULE_MODE:-0}
    BLOCKY_RULE_MODE=$(( (current_mode + 1) % 3 ))

    case "$BLOCKY_RULE_MODE" in
        0) STATUS_MESSAGE="Blocky Mode set to VERTICAL. Resetting grid..." ;; 
        1) STATUS_MESSAGE="Blocky Mode set to ISOLATED. Resetting grid..." ;; 
        2) STATUS_MESSAGE="Blocky Mode set to STRIPES. Resetting grid..." ;; 
    esac
    log_event "$STATUS_MESSAGE"
    
    # Force a grid reset using the new mode
    if declare -F init_grid &>/dev/null; then
        init_grid # Reload grid using the new BLOCKY_RULE_MODE value
    else
        STATUS_MESSAGE="Error: init_grid not found to reset for mode change."
        log_error "$STATUS_MESSAGE"
    fi
    return 1 # Require redraw after mode change and reset
}

# --- Toggle Run/Pause State ---
action_toggle_run() {
    if [[ $RUNNING -eq 1 ]]; then
        RUNNING=0
        STATUS_MESSAGE="Paused"
        log_event "Toggled running state to $RUNNING"
    else
        RUNNING=1
        STATUS_MESSAGE="Running..."
        log_event "Toggled running state to $RUNNING"
    fi
}

# ... (Rest of input.sh - _process_input, handle_input using the globally defined KEY_ACTIONS) ...


