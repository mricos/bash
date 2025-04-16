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
action_next_format() {
    local -a formats_available=(); [[ -v AVAILABLE_FORMATS[ASCII] ]] && formats_available+=("ASCII"); [[ -v AVAILABLE_FORMATS[ENHANCED] ]] && formats_available+=("ENHANCED"); [[ -v AVAILABLE_FORMATS[TILED] ]] && formats_available+=("TILED")
    local current_index=-1; for i in "${!formats_available[@]}"; do if [[ "${formats_available[$i]}" == "$CURRENT_RENDER_FORMAT" ]]; then current_index=$i; break; fi; done
    if [[ $current_index -ne -1 && ${#formats_available[@]} -gt 1 ]]; then local next_index=$(( (current_index + 1) % ${#formats_available[@]} )); CURRENT_RENDER_FORMAT="${formats_available[$next_index]}"; STATUS_MESSAGE="Render Format: $CURRENT_RENDER_FORMAT"; log_event "Switched Render Format to $CURRENT_RENDER_FORMAT";
    elif [[ ${#formats_available[@]} -le 1 ]]; then STATUS_MESSAGE="Only one Render Format available: $CURRENT_RENDER_FORMAT"; fi
}
action_prev_format() {
    local -a formats_available=(); [[ -v AVAILABLE_FORMATS[ASCII] ]] && formats_available+=("ASCII"); [[ -v AVAILABLE_FORMATS[ENHANCED] ]] && formats_available+=("ENHANCED"); [[ -v AVAILABLE_FORMATS[TILED] ]] && formats_available+=("TILED")
    local current_index=-1; for i in "${!formats_available[@]}"; do if [[ "${formats_available[$i]}" == "$CURRENT_RENDER_FORMAT" ]]; then current_index=$i; break; fi; done
     if [[ $current_index -ne -1 && ${#formats_available[@]} -gt 1 ]]; then local prev_index=$(( (current_index - 1 + ${#formats_available[@]}) % ${#formats_available[@]} )); CURRENT_RENDER_FORMAT="${formats_available[$prev_index]}"; STATUS_MESSAGE="Render Format: $CURRENT_RENDER_FORMAT"; log_event "Switched Render Format to $CURRENT_RENDER_FORMAT";
    elif [[ ${#formats_available[@]} -le 1 ]]; then STATUS_MESSAGE="Only one Render Format available: $CURRENT_RENDER_FORMAT"; fi
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

# --- Keybinding Setup ---
# Populates the global KEY_ACTIONS associative array.
setup_keybindings() {
    # Uses KEY_ACTIONS from engine_config_state.sh
    KEY_ACTIONS=(
        [q]="action_quit"
        [" "]="action_toggle_run"      # Space bar
        [c]="action_step"
        [f]="action_toggle_fullscreen" # Toggle between small/large render
        [e]="action_toggle_empty_view"

        # Algorithm Selection (Works in both modes)
        [k]="action_prev_algo"         # Prev algo
        [j]="action_next_algo"         # Next algo

        # Format Selection (Works in both modes, effect mainly visible in large)
        [u]="action_prev_format"       # Prev render format
        [i]="action_next_format"       # Next render format

        # Doc Page Navigation (Works in both modes)
        [p]="action_prev_doc_page"     # Prev doc page
        [n]="action_next_doc_page"     # Next doc page

        # Keys to pass directly to algorithms (Works in both modes)
        [a]="action_pass_to_algo a"
        [s]="action_pass_to_algo s"
        [d]="action_pass_to_algo d"
        [w]="action_pass_to_algo w"
        [h]="action_pass_to_algo h"
        [l]="action_pass_to_algo l"
        [';']="action_pass_to_algo ;"

        # Arrow Keys (Mainly for Fullscreen / Large mode navigation)
        # These map ANSI escape sequences for arrow keys
        # Note: The main loop needs to handle reading these sequences correctly
        [$'\e[A']="action_prev_format" # Up Arrow    -> Prev Format (in fullscreen)
        [$'\e[B']="action_next_format" # Down Arrow  -> Next Format (in fullscreen)
        [$'\e[C']="action_next_algo"   # Right Arrow -> Next Algo (in fullscreen)
        [$'\e[D']="action_prev_algo"   # Left Arrow  -> Prev Algo (in fullscreen)
    )
    log_event "Keybindings set up, including arrow keys for fullscreen."
    # Debug: List keys
    # for k in "${!KEY_ACTIONS[@]}"; do printf "'%q' -> %s\n" "$k" "${KEY_ACTIONS[$k]}"; done >&2
}


