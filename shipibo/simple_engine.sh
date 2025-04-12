#!/usr/bin/env bash

# Simple engine that loads and runs algorithm files

# --- Configuration ---
ROWS=15
COLS=30
RUNNING=0           # Start paused
SHOULD_EXIT=0       # Exit flag
FULL_SCREEN=0       # Toggle for full screen mode
EMPTY_DISPLAY=0     # Toggle for replacing dots with spaces
# Define available algorithms
declare -a ALGO_FILES=("snake.sh" "wfc-basic.sh" "wfc.sh" "grid2.sh" "blocky.sh" "ca.sh") # Add ca.sh
CURRENT_ALGO_INDEX=2 # Start with the third algorithm (wfc.sh)
ALGO_FILE="${ALGO_FILES[$CURRENT_ALGO_INDEX]}" # Currently selected file
STATUS_MESSAGE=""
CURRENT_PAGE=0
DEBUG_LOG_FILE="debug.log" # Define log file
export DEBUG_LOG_FILE       # Export for sourced scripts

# Explicitly declare shared data structures with global scope
# These will be reset when switching algorithms
declare -gA grid
declare -gA possibilities
declare -gA collapsed
declare -gA rules
declare -ga SYMBOLS
declare -ga PAGES

# --- Initialization ---
# Clear the debug log at the start
> "$DEBUG_LOG_FILE"

# --- Helper Function to Load and Initialize Algorithm ---
load_and_init_algorithm() {
    local index=$1
    if [[ -z "${ALGO_FILES[$index]}" ]]; then
        STATUS_MESSAGE="Error: Invalid algorithm index $index"
        echo "ERROR: Invalid algorithm index $index" >> "$DEBUG_LOG_FILE"
        return 1
    fi

    CURRENT_ALGO_INDEX=$index
    ALGO_FILE="${ALGO_FILES[$CURRENT_ALGO_INDEX]}"
    STATUS_MESSAGE="Loading ${ALGO_FILE}..."
    render # Show loading message quickly

    if [[ ! -f "$ALGO_FILE" ]]; then
        STATUS_MESSAGE="Error: Algorithm file not found: $ALGO_FILE"
        echo "ERROR: Algorithm file not found: $ALGO_FILE" >> "$DEBUG_LOG_FILE"
        # Optionally reset to default or handle error
        # For now, just show error and pause
        RUNNING=0
        return 1
    fi

    # Reset state before loading new algorithm
    grid=()
    possibilities=()
    collapsed=()
    rules=()
    SYMBOLS=()
    PAGES=()
    CURRENT_PAGE=0
    RUNNING=0 # Stop running when switching

    # Source the new algorithm
    echo "DEBUG: Sourcing ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
    source "$ALGO_FILE"
    echo "DEBUG: After sourcing ${ALGO_FILE}, PAGES has ${#PAGES[@]} elements" >> "$DEBUG_LOG_FILE"

    # Initialize the new algorithm (assuming functions exist)
    if declare -F init_rules &>/dev/null; then
        echo "DEBUG: Initializing rules for ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
        init_rules
    else
        echo "WARN: init_rules not found in ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
    fi

    if declare -F init_grid &>/dev/null; then
        echo "DEBUG: Initializing grid for ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
        init_grid
        echo "DEBUG: After init_grid, grid has ${#grid[@]} elements" >> "$DEBUG_LOG_FILE"
    else
         echo "WARN: init_grid not found in ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
         # Basic grid init if function missing
         for ((y=0; y<ROWS; y++)); do for ((x=0; x<COLS; x++)); do collapsed["$y,$x"]=0; done; done
    fi

    STATUS_MESSAGE="Loaded ${ALGO_FILE}"
    echo "INFO: Successfully loaded and initialized ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
    return 0
}

# --- Double Buffer Rendering ---
render() {
    # Redirect debug output for troubleshooting to the log file
    echo "DEBUG (render): PAGES array has ${#PAGES[@]} elements" >> "$DEBUG_LOG_FILE"

    # Store grid lines and text lines separately
    local -a grid_lines=()
    local -a text_lines=() # Combine pages, status, controls here

    # --- Build Grid Lines ---
    for ((y=0; y<ROWS; y++)); do
        local line=""
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            if [[ "${collapsed[$key]}" == "1" ]]; then
                line+="${grid[$key]:-?}"
            else
                if [[ $EMPTY_DISPLAY -eq 1 ]]; then
                    line+=" " # Use space instead of dots/entropy indicators
                else
                    local -a opts=(${possibilities[$key]})
                    local entropy=${#opts[@]}
                    if (( entropy <= 1 )); then line+="·";
                    elif (( entropy <= 3 )); then line+=":";
                    else line+="·";
                    fi
                fi
            fi
        done
        grid_lines+=("$line")
    done

    # --- Build Text Lines (Right Panel) ---
    text_lines+=("WFC Engine - $(date +%H:%M:%S)")
    text_lines+=("----------------------------------------")
    text_lines+=("Algorithm: ${ALGO_FILE} [$((CURRENT_ALGO_INDEX+1))/${#ALGO_FILES[@]}]") # Show current algo
    text_lines+=("Status: $([[ $RUNNING -eq 1 ]] && echo "Running" || echo "Paused")")
    text_lines+=("Message: $STATUS_MESSAGE")
    text_lines+=("----------------------------------------")

    # Page content
    if [[ ${#PAGES[@]} -gt 0 ]]; then
        text_lines+=("PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}")
        text_lines+=("----------------------------------------")
        IFS=$'\n' read -d '' -ra content_lines <<< "${PAGES[$CURRENT_PAGE]}"
        for line in "${content_lines[@]}"; do text_lines+=("$line"); done
        text_lines+=("----------------------------------------")
    else
        text_lines+=("NO DOC PAGES FOUND")
        text_lines+=("----------------------------------------")
    fi

    # Collapsed cell count
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    text_lines+=("Collapsed: $collapsed_count / $((ROWS*COLS))")
    text_lines+=("----------------------------------------")

    # Controls - updated to show algorithm switching
    text_lines+=("Controls:")
    text_lines+=("[s] Start/Stop | [c] Step")
    text_lines+=("[n] Next Page  | [p] Prev Page")
    text_lines+=("[1-${#ALGO_FILES[@]}] Select Algorithm | [f] Full Screen | [e] Empty View | [q] Quit")

    # --- Render Based on Mode ---
    printf "\033[H\033[J" # Clear screen and move cursor to home

    if [[ $FULL_SCREEN -eq 1 ]]; then
        # Get terminal dimensions
        local term_rows=$(tput lines)
        local term_cols=$(tput cols)
        
        # Calculate centering offsets
        local row_offset=$(( (term_rows - ROWS) / 2 ))
        local col_offset=$(( (term_cols - COLS) / 2 ))
        
        # Skip negative offsets (terminal too small)
        [[ $row_offset -lt 0 ]] && row_offset=0
        [[ $col_offset -lt 0 ]] && col_offset=0
        
        # Move to offset position and display centered grid
        for ((i=0; i<row_offset; i++)); do
            echo ""
        done
        
        for line in "${grid_lines[@]}"; do
            printf "%${col_offset}s%s\n" "" "$line"
        done
    else
        # Regular side-by-side display
        local grid_width=$COLS
        local text_width=40 # Adjust as needed
        local max_rows=$((${#grid_lines[@]} > ${#text_lines[@]} ? ${#grid_lines[@]} : ${#text_lines[@]}))

        for ((i=0; i<max_rows; i++)); do
            local grid_content=""
            local text_content=""
            if ((i < ${#grid_lines[@]})); then grid_content="${grid_lines[$i]}"; fi
            if ((i < ${#text_lines[@]})); then text_content="${text_lines[$i]}"; fi
            printf "%-${grid_width}s   %s\n" "$grid_content" "$text_content"
        done
    fi
}

# --- Main Loop ---
main() {
    # Initial load of the default algorithm
    load_and_init_algorithm $CURRENT_ALGO_INDEX
    if [[ $? -ne 0 ]]; then
        # Handle case where initial default algo failed to load
        echo "Error loading initial algorithm ${ALGO_FILES[$CURRENT_ALGO_INDEX]}. Exiting."
        exit 1
    fi

    # Setup terminal
    tput civis  # Hide cursor
    # clear # Don't clear here, render will do it

    # Main loop
    while [[ $SHOULD_EXIT -eq 0 ]]; do

        local key_pressed=0 # Flag to check if input was received

        # Process algorithm if running
        if [[ $RUNNING -eq 1 ]]; then
            # Ensure update_algorithm function exists before calling
            if declare -F update_algorithm &>/dev/null; then
                # echo "DEBUG (main loop): Calling update_algorithm for ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
                update_algorithm # Modifies STATUS_MESSAGE globally
                local exit_code=$?
                # echo "DEBUG (main loop): ${ALGO_FILE} finished with exit code $exit_code" >> "$DEBUG_LOG_FILE"
                if [[ $exit_code -ne 0 ]]; then
                     RUNNING=0 # Stop running if algorithm returns non-zero
                fi
            else
                 STATUS_MESSAGE="Error: update_algorithm not found in ${ALGO_FILE}"
                 echo "ERROR: update_algorithm not found in ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
                 RUNNING=0 # Stop if function missing
            fi
            # Render immediately after processing when running
            render
        fi # End if running

        # Check for input regardless of running state
        read -s -n 1 -t 0.01 key # Short timeout allows responsiveness
        if [[ -n "$key" ]]; then
             key_pressed=1 # Mark that input was received
             case "$key" in
                 [1-9]) # Handle number input for algorithm selection
                     local selected_index=$((key - 1)) # Convert key '1' to index 0, etc.
                     if [[ "$selected_index" -lt "${#ALGO_FILES[@]}" && "$selected_index" -ne "$CURRENT_ALGO_INDEX" ]]; then
                          echo "DEBUG (input): Switching to algorithm index $selected_index" >> "$DEBUG_LOG_FILE"
                          load_and_init_algorithm "$selected_index"
                          # Re-render needed after loading new algo
                     elif [[ "$selected_index" -ge "${#ALGO_FILES[@]}" ]]; then
                          STATUS_MESSAGE="Invalid algorithm number: $key"
                          echo "WARN (input): Invalid algorithm number $key" >> "$DEBUG_LOG_FILE"
                          # Re-render needed to show status message
                     else
                          key_pressed=0 # No change occurred, don't re-render if paused
                     fi
                     ;;
                 s) # Start/Stop
                     RUNNING=$((1-RUNNING))
                     if [[ $RUNNING -eq 1 ]]; then STATUS_MESSAGE="Running..."; else STATUS_MESSAGE="Paused"; fi
                     echo "DEBUG (input): Toggled running state to $RUNNING" >> "$DEBUG_LOG_FILE"
                     # Re-render needed to show status update
                     ;;
                 c) # Step (Collapse One)
                     if declare -F update_algorithm > /dev/null; then
                         if [[ $RUNNING -eq 0 ]]; then # Only allow step if paused
                             echo "DEBUG (input): Manual step requested for ${ALGO_FILE}" >> "$DEBUG_LOG_FILE"
                             update_algorithm
                             local exit_code=$?
                             if [[ $exit_code -ne 0 ]]; then RUNNING=0; fi # Stop if it finishes/errors
                             echo "DEBUG (input): Manual step finished for ${ALGO_FILE} (code $exit_code)" >> "$DEBUG_LOG_FILE"
                             # Re-render needed after step
                         else
                             STATUS_MESSAGE="Pause ([s]) before stepping ([c])"
                             # Re-render needed to show status message
                         fi
                     else
                         STATUS_MESSAGE="Error: update_algorithm not found"
                         echo "ERROR: update_algorithm not found (manual step)" >> "$DEBUG_LOG_FILE"
                         # Re-render needed to show error
                     fi
                     ;;
                 n) # Next Page
                     if [[ ${#PAGES[@]} -gt 0 ]]; then
                         local old_page=$CURRENT_PAGE
                         CURRENT_PAGE=$(( (CURRENT_PAGE + 1) % ${#PAGES[@]} ))
                         if [[ $old_page != $CURRENT_PAGE ]]; then
                            STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                            echo "DEBUG (input): Changed to page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                            # If current algo is ca.sh, re-init grid based on new page
                            if [[ "$ALGO_FILE" == "ca.sh" ]] && declare -F init_grid &>/dev/null; then
                                echo "DEBUG (input): Re-initializing ca.sh grid for new page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                                init_grid $CURRENT_PAGE # Pass current page index
                                # init_grid sets RUNNING=0 and STATUS_MESSAGE
                            fi
                         else
                             key_pressed=0 # Page didn't change (e.g., only 1 page)
                         fi
                     else
                         STATUS_MESSAGE="No pages available"
                         echo "DEBUG (input): No pages to navigate (next)" >> "$DEBUG_LOG_FILE"
                         # Re-render needed to show status
                     fi
                     ;;
                 p) # Previous Page
                      if [[ ${#PAGES[@]} -gt 0 ]]; then
                         local old_page=$CURRENT_PAGE
                         CURRENT_PAGE=$(( (CURRENT_PAGE - 1 + ${#PAGES[@]}) % ${#PAGES[@]} ))
                         if [[ $old_page != $CURRENT_PAGE ]]; then
                            STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                            echo "DEBUG (input): Changed to page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                            # If current algo is ca.sh, re-init grid based on new page
                            if [[ "$ALGO_FILE" == "ca.sh" ]] && declare -F init_grid &>/dev/null; then
                                echo "DEBUG (input): Re-initializing ca.sh grid for new page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                                init_grid $CURRENT_PAGE # Pass current page index
                                # init_grid sets RUNNING=0 and STATUS_MESSAGE
                            fi
                         else
                            key_pressed=0 # Page didn't change
                         fi
                     else
                         STATUS_MESSAGE="No pages available"
                         echo "DEBUG (input): No pages to navigate (prev)" >> "$DEBUG_LOG_FILE"
                         # Re-render needed to show status
                     fi
                     ;;
                 q) SHOULD_EXIT=1 ;; # Set flag, will exit on next loop check
                 f) # Toggle full screen mode
                     FULL_SCREEN=$((1-FULL_SCREEN))
                     STATUS_MESSAGE="Full screen mode: $([[ $FULL_SCREEN -eq 1 ]] && echo "ON" || echo "OFF")"
                     echo "DEBUG (input): Toggled full screen mode to $FULL_SCREEN" >> "$DEBUG_LOG_FILE"
                     ;;
                 e) # Toggle empty display mode
                     EMPTY_DISPLAY=$((1-EMPTY_DISPLAY))
                     STATUS_MESSAGE="Empty display mode: $([[ $EMPTY_DISPLAY -eq 1 ]] && echo "ON" || echo "OFF")"
                     echo "DEBUG (input): Toggled empty display mode to $EMPTY_DISPLAY" >> "$DEBUG_LOG_FILE"
                     ;;
                 *) key_pressed=0 ;; # Unrecognized key, don't re-render if paused
             esac
        fi # End if key pressed

        # Only render when paused IF a valid key was pressed and processed
        if [[ $RUNNING -eq 0 && $key_pressed -eq 1 ]]; then
             render
        fi

        # Loop exit condition
        if [[ $SHOULD_EXIT -eq 1 ]]; then break; fi

        # If paused and no key was pressed, the loop naturally continues
        # after the read timeout without processing or rendering.

    done # End main loop

    # Clean up terminal
    tput cnorm  # Show cursor
    clear
    echo "Goodbye!"
}

# Clean up on exit
trap 'tput cnorm; clear; exit' INT TERM EXIT

# Start the engine
main
