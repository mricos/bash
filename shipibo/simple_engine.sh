#!/usr/bin/env bash

# Simple engine that loads and runs algorithm files

# --- Configuration ---
ROWS=15
COLS=30
RUNNING=0           # Start paused
SHOULD_EXIT=0       # Exit flag
ALGO_FILE="simple_algo.sh"
STATUS_MESSAGE=""
CURRENT_PAGE=0

# Explicitly declare shared data structures with global scope
declare -gA grid          # -g flag makes it global
declare -gA possibilities  
declare -gA collapsed     
declare -gA rules
declare -ga SYMBOLS
declare -ga PAGES

# --- Double Buffer Rendering ---
render() {
    # Debug output for troubleshooting
    echo "DEBUG: PAGES array has ${#PAGES[@]} elements" >&2
    
    # Build buffer for efficient rendering
    local buffer=""
    buffer+="Wave Function Collapse - $(date +%H:%M:%S)\n"
    buffer+="Status: $([[ $RUNNING -eq 1 ]] && echo "Running" || echo "Paused")\n"
    buffer+="Message: $STATUS_MESSAGE\n"
    
    # Display page content
    buffer+="----------------------------------------\n"
    if [[ ${#PAGES[@]} -gt 0 ]]; then
        buffer+="PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}\n"
        buffer+="----------------------------------------\n"
        
        # For cleaner page display, split into lines and process one by one
        IFS=$'\n' read -d '' -ra page_lines <<< "${PAGES[$CURRENT_PAGE]}"
        for line in "${page_lines[@]}"; do
            # Add each line to the buffer with fixed width formatting
            buffer+="${line}\n"
        done
        
        buffer+="----------------------------------------\n"
    else
        buffer+="NO PAGES FOUND\n"
        buffer+="----------------------------------------\n"
    fi
    
    # Debug: count collapsed cells to verify algorithm progress
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do
        if [[ "${collapsed[$k]}" == "1" ]]; then
            ((collapsed_count++))
        fi
    done
    buffer+="Collapsed cells: $collapsed_count/${ROWS}x${COLS}\n"
    buffer+="----------------------------------------\n"
    
    # Build grid in buffer
    for ((y=0; y<ROWS; y++)); do
        local line=""
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            if [[ "${collapsed[$key]}" == "1" ]]; then
                line+="${grid[$key]:-?}"  # Add fallback character if missing
            else
                # Show entropy visually - more options = brighter dot
                local -a opts=(${possibilities[$key]})
                local entropy=${#opts[@]}
                if (( entropy <= 1 )); then
                    line+="·" # Lowest entropy
                elif (( entropy <= 3 )); then
                    line+=":" # Medium entropy
                else
                    line+="·" # High entropy
                fi
            fi
        done
        
        buffer+="$line\n"
    done
    
    buffer+="----------------------------------------\n"
    buffer+="Controls: [s] Start/Stop | [c] Collapse One | [n] Next Page | [p] Prev Page | [q] Quit\n"
    
    # Position cursor at home and output buffer
    printf "\033[H"
    printf "%b" "$buffer"
}

# --- Main Loop ---
main() {
    # Source algorithm file
    if [[ ! -f "$ALGO_FILE" ]]; then
        echo "Algorithm file not found: $ALGO_FILE"
        exit 1
    fi
    
    # Source the algorithm - this should define PAGES, SYMBOLS, etc.
    source "$ALGO_FILE"
    
    # DEBUG: Check that PAGES was loaded
    echo "DEBUG: After sourcing, PAGES has ${#PAGES[@]} elements" >&2
    
    # Initialize the algorithm
    echo "DEBUG: Initializing rules" >&2
    init_rules
    echo "DEBUG: Initializing grid" >&2
    init_grid
    
    # Setup terminal
    tput civis  # Hide cursor
    clear
    
    # Main loop
    while [[ $SHOULD_EXIT -eq 0 ]]; do
        # Process algorithm if running
        if [[ $RUNNING -eq 1 ]]; then
            # Call update_algorithm directly. It modifies grid, collapsed,
            # and STATUS_MESSAGE globally.
            update_algorithm
            # Check the return code to see if the algorithm finished or had an error
            if [[ $? -ne 0 ]]; then
                 RUNNING=0 # Stop running if algorithm returns non-zero
                 # The algorithm already set STATUS_MESSAGE on completion/error
            fi
        fi
        
        # Render screen
        render
        
        # Check for input with a short timeout
        read -s -n 1 -t 0.1 key
        case "$key" in
            s)
                RUNNING=$((1-RUNNING))
                # Update status message immediately when pausing/resuming
                if [[ $RUNNING -eq 1 ]]; then
                    STATUS_MESSAGE="Running..." # Or keep the last message from the algo
                else
                    STATUS_MESSAGE="Paused"
                fi
                ;;
            c)
                if declare -F update_algorithm > /dev/null; then
                    # Call update_algorithm directly for manual collapse
                    update_algorithm
                    if [[ $? -ne 0 ]]; then
                        RUNNING=0 # Stop if it finishes/errors
                    fi
                fi
                ;;
            n)
                # SUPER DIRECT page navigation
                if [[ ${#PAGES[@]} -gt 0 ]]; then
                    CURRENT_PAGE=$(( (CURRENT_PAGE + 1) % ${#PAGES[@]} ))
                    echo "DEBUG: CHANGED TO PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}" >&2
                    STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                else
                    echo "DEBUG: NO PAGES TO NAVIGATE" >&2
                    STATUS_MESSAGE="No pages available"
                fi
                ;;
            p)
                # Previous page
                if [[ ${#PAGES[@]} -gt 0 ]]; then
                    CURRENT_PAGE=$(( (CURRENT_PAGE - 1 + ${#PAGES[@]}) % ${#PAGES[@]} ))
                    echo "DEBUG: CHANGED TO PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}" >&2
                    STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                fi
                ;;
            q) SHOULD_EXIT=1 ;;
        esac
    done
    
    # Clean up terminal
    tput cnorm  # Show cursor
    clear
    echo "Goodbye!"
}

# Clean up on exit
trap 'tput cnorm; clear; exit' INT TERM EXIT

# Start the engine
main
