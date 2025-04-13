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

# --- Global State (Managed by Engine & Algos) ---
declare -ga grid_lines_1x1
declare -ga grid_lines_nxn
declare -ga text_lines
# Global algo metadata (set by algos)
declare -g ALGO_TILE_WIDTH=1
declare -g ALGO_TILE_HEIGHT=1
# Global TILE data (set by relevant algos like grid2.sh)
declare -gA TILE_TOPS
declare -gA TILE_BOTS
declare -gA TILE_NAME_TO_CHAR # Used by grid2.sh

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

# --- Rendering Helper Functions ---

_build_grid_lines_1x1() {
    grid_lines_1x1=() # Clear global array
    local current_error_symbol="${ERROR_SYMBOL:-X}" # Algo error symbol or 'X'
    # Check if the current algo provides TILE_NAME_TO_CHAR mapping
    local can_map_names=0
    [[ "$(declare -p TILE_NAME_TO_CHAR 2>/dev/null)" == "declare -A"* ]] && can_map_names=1

    echo "DEBUG (render_1x1): Building..." >> "$DEBUG_LOG_FILE"
    for ((y=0; y<ROWS; y++)); do
        local line=""
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            if [[ "${collapsed[$key]:-0}" == "1" ]]; then
                local cell_content_name="${grid[$key]:-?}" # Get name/content from grid
                local display_char="?"
                if [[ "$cell_content_name" == "$current_error_symbol" ]]; then
                     display_char="${TILE_NAME_TO_CHAR[$current_error_symbol]:-$current_error_symbol}" # Mapped error or raw
                elif [[ $can_map_names -eq 1 && -v TILE_NAME_TO_CHAR[$cell_content_name] ]]; then
                     display_char="${TILE_NAME_TO_CHAR[$cell_content_name]}" # Mapped char
                else
                     display_char="${cell_content_name:0:1}" # Fallback: first char
                fi
                 line+="$display_char"
            else # Uncollapsed
                if [[ $EMPTY_DISPLAY -eq 1 ]]; then line+=" "; else
                    local opts_str="${possibilities[$key]-}" # Use possibilities array
                    local entropy=${#opts_str}
                    if [[ $entropy == 0 && "${collapsed[$key]:-0}" != "1" ]]; then line+="${current_error_symbol}"; else
                    if (( entropy <= 1 )); then line+="·"; elif (( entropy <= 3 )); then line+=":"; else line+="·"; fi; fi
                fi
            fi
        done
        grid_lines_1x1+=("$line")
    done
     echo "DEBUG (render_1x1): Built ${#grid_lines_1x1[@]} lines." >> "$DEBUG_LOG_FILE"
}

_build_grid_lines_nxn() {
    grid_lines_nxn=() # Clear global array
    local current_error_symbol="${ERROR_SYMBOL:-?}"
    local tile_w=${ALGO_TILE_WIDTH:-1} # Use globals set by render dispatcher
    local tile_h=${ALGO_TILE_HEIGHT:-1}

    # Check if TILE data is valid
    if ! declare -p TILE_TOPS &>/dev/null || ! declare -p TILE_BOTS &>/dev/null \
           || [[ "$(declare -p TILE_TOPS)" != "declare -A"* ]] || [[ "$(declare -p TILE_BOTS)" != "declare -A"* ]]; then
        echo "ERROR (render_nxn): TILE_TOPS/BOTS arrays not valid." >> "$DEBUG_LOG_FILE"
        grid_lines_nxn+=("ERROR: Missing TILE data") # Add error line
        return 1 # Indicate failure
    fi

    echo "DEBUG (render_nxn): Building ${tile_w}x${tile_h} lines..." >> "$DEBUG_LOG_FILE"
    local sample_glyph_width=7; if [[ -v TILE_TOPS[STRAIGHT_H] ]]; then sample_glyph_width=${#TILE_TOPS[STRAIGHT_H]}; [[ $sample_glyph_width -lt 1 ]] && sample_glyph_width=1; fi
    local placeholder_error="!ERROR!"; local placeholder_unk="??UNK??"; local placeholder_uncol="......."
    printf -v placeholder_error "%-*.*s" $sample_glyph_width $sample_glyph_width "$placeholder_error"
    printf -v placeholder_unk "%-*.*s" $sample_glyph_width $sample_glyph_width "$placeholder_unk"
    printf -v placeholder_uncol "%-*.*s" $sample_glyph_width $sample_glyph_width "$placeholder_uncol"

    for ((y=0; y<ROWS; y++)); do
        for ((ty=0; ty<tile_h; ty++)); do
            local current_line=""
            for ((x=0; x<COLS; x++)); do
                local key="$y,$x"; local glyph_segment=""; local collapsed_status="${collapsed[$key]:-0}"
                if [[ "$collapsed_status" == "1" ]]; then
                    local tile_name="${grid[$key]:-UNK}" # Get name from grid
                    if [[ "$tile_name" == "$current_error_symbol" ]]; then glyph_segment="$placeholder_error"
                    elif [[ "$tile_name" == "UNK" ]] || ! [[ -v TILE_TOPS[$tile_name] ]]; then glyph_segment="$placeholder_unk"
                    else
                        if (( ty == 0 )); then glyph_segment="${TILE_TOPS[$tile_name]}"
                        elif (( ty == 1 && tile_h >= 2 )); then glyph_segment="${TILE_BOTS[$tile_name]}"
                        else glyph_segment="$placeholder_unk"; fi
                        [[ -z "$glyph_segment" ]] && glyph_segment="$placeholder_unk"
                    fi
                else glyph_segment="$placeholder_uncol"; fi
                current_line+="${glyph_segment} "
            done; grid_lines_nxn+=("${current_line% }")
        done
    done
    echo "DEBUG (render_nxn): Built ${#grid_lines_nxn[@]} lines." >> "$DEBUG_LOG_FILE"
    return 0 # Indicate success
}

_build_text_lines() {
    text_lines=() # Clear global array
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}
    text_lines+=("WFC Engine - $(date +%H:%M:%S)"); text_lines+=("----------------------------------------")
    text_lines+=("Algorithm: ${ALGO_FILE} [$((CURRENT_ALGO_INDEX+1))/${#ALGO_FILES[@]}] (${tile_w}x${tile_h})")
    text_lines+=("Status: $([[ $RUNNING -eq 1 ]] && echo "Running" || echo "Paused")"); text_lines+=("Message: $STATUS_MESSAGE"); text_lines+=("----------------------------------------")
    if [[ ${#PAGES[@]} -gt 0 ]]; then text_lines+=("PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}"); text_lines+=("----------------------------------------"); IFS=$'\n' read -d '' -ra content_lines <<< "${PAGES[$CURRENT_PAGE]}"; for line in "${content_lines[@]}"; do text_lines+=("$line"); done; text_lines+=("----------------------------------------"); else text_lines+=("NO DOC PAGES FOUND"); text_lines+=("----------------------------------------"); fi
    local collapsed_count=0; for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done; text_lines+=("Collapsed: $collapsed_count / $((ROWS*COLS))"); text_lines+=("----------------------------------------")
    text_lines+=("Controls:"); text_lines+=("[s] Start/Stop | [c] Step"); text_lines+=("[n] Next Page  | [p] Prev Page"); text_lines+=("[1-${#ALGO_FILES[@]}] Select Algorithm | [f] Full Screen | [e] Empty View | [q] Quit")
}

# --- Main Rendering Functions ---

render_small() { # Side-by-side mode
    _build_grid_lines_1x1
    _build_text_lines

    local buffer=""
    echo "DEBUG (render): Using SIDE-BY-SIDE mode." >> "$DEBUG_LOG_FILE"
    local term_cols=$(tput cols); local desired_text_width=40; local panel_spacing=3
    local grid_panel_width=$COLS
    local max_text_width=$(( term_cols - grid_panel_width - panel_spacing )); [[ $max_text_width -lt 0 ]] && max_text_width=0
    local actual_text_width=$(( desired_text_width < max_text_width ? desired_text_width : max_text_width )); [[ $actual_text_width -lt 0 ]] && actual_text_width=0
    local max_rows=$((${#grid_lines_1x1[@]} > ${#text_lines[@]} ? ${#grid_lines_1x1[@]} : ${#text_lines[@]}))

    for ((i=0; i<max_rows; i++)); do
        local grid_content=""; local text_content=""
        if ((i < ${#grid_lines_1x1[@]})); then grid_content="${grid_lines_1x1[$i]:0:$grid_panel_width}"; fi
        if ((i < ${#text_lines[@]})); then text_content="${text_lines[$i]:0:$actual_text_width}"; fi

        # Create the line string WITHOUT newline first
        local line_str
        line_str=$(printf "%-${grid_panel_width}s%${panel_spacing}s%s" "$grid_content" "" "$text_content")

        # Append the line string and a literal newline character sequence to buffer
        buffer+="${line_str}\\n" # Append literal backslash-n
    done

    # Return the assembled buffer. The main render function will print it.
    # Use printf %b to interpret the \n sequences when captured.
    printf "%b" "$buffer"
}

render_large() { # Full screen mode
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}
    local build_nxn_success=0
    local buffer="" # Buffer for the complete output

    echo "DEBUG (render): Using FULL SCREEN mode." >> "$DEBUG_LOG_FILE"
    local -n current_grid_lines_ref=grid_lines_1x1 # Default ref
    local grid_display_height=$ROWS
    local grid_char_width=$COLS # Default width

    if (( tile_w > 1 || tile_h > 1 )); then
        if _build_grid_lines_nxn; then
             echo "DEBUG (render): Full screen - Build NxN SUCCESS. Using NxN lines." >> "$DEBUG_LOG_FILE"
             current_grid_lines_ref=grid_lines_nxn # Switch ref to NxN lines
             grid_display_height=$(( ROWS * tile_h ))
             # Calculate NxN width more accurately
             if [[ ${#current_grid_lines_ref[@]} -gt 0 ]]; then
                 # Use the length of the first line as representative width
                 grid_char_width=${#current_grid_lines_ref[0]}
             else
                 # Fallback if array is empty (shouldn't happen on success)
                 grid_char_width=$(( COLS * tile_w )) # Estimate
             fi
             build_nxn_success=1
        else
             echo "WARN (render): Full screen - Build NxN FAILED. Falling back to 1x1." >> "$DEBUG_LOG_FILE"
             _build_grid_lines_1x1 # Ensure 1x1 is built
             current_grid_lines_ref=grid_lines_1x1 # Keep ref as 1x1
             grid_display_height=$ROWS
             grid_char_width=$COLS
        fi
    else
        # If 1x1 algo, build and use 1x1 lines
        _build_grid_lines_1x1
        echo "DEBUG (render): Full screen - Using 1x1 lines." >> "$DEBUG_LOG_FILE"
        current_grid_lines_ref=grid_lines_1x1
        grid_display_height=$ROWS
        grid_char_width=$COLS
    fi

    # Get current terminal dimensions *just before* calculating offsets
    local term_rows=$(tput lines); local term_cols=$(tput cols)
    local row_offset=$(( (term_rows - grid_display_height) / 2 )); local col_offset=$(( (term_cols - grid_char_width) / 2 ))
    [[ $row_offset -lt 0 ]] && row_offset=0; [[ $col_offset -lt 0 ]] && col_offset=0

    # Add cursor positioning command to buffer first
    buffer+=$(printf "\033[$((row_offset + 1));${col_offset}H")

    for ((i=0; i<${#current_grid_lines_ref[@]}; i++)); do
        local line_content="${current_grid_lines_ref[$i]}"
        # Append line content and cursor move command for the *next* line
        # Ensure line_content doesn't contain unexpected newlines itself
        line_content=${line_content//$'\n'/ } # Replace potential newlines in grid data with spaces
        buffer+=$(printf "%s\033[$((row_offset + i + 2));${col_offset}H" "$line_content")
    done

    # Return the assembled buffer (which includes ANSI escape codes)
    printf "%s" "$buffer" # Print raw buffer with escapes
}

# --- Main Render Dispatcher ---
render() {
    local output_buffer=""
    if [[ $FULL_SCREEN -eq 1 ]]; then
        output_buffer=$(render_large) # Capture output from function
    else
        output_buffer=$(render_small) # Capture output from function
    fi
    # Clear screen THEN print the entire buffer at once
    # Use %b to interpret potential \n sequences from render_small
    printf "\033[H\033[J%b" "$output_buffer"
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
                 q)
                     echo "DEBUG (input): Quit key pressed." >> "$DEBUG_LOG_FILE"
                     SHOULD_EXIT=1
                     key_pressed=1 # Ensure render happens if paused
                     ;;
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
