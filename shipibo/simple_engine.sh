#!/usr/bin/env bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8

# --- Configuration ---
ROWS=15
COLS=30
RUNNING=0
SHOULD_EXIT=0
FULL_SCREEN=0
EMPTY_DISPLAY=0

declare -a ALGO_FILES=("snake.sh" "wfc-basic.sh" "wfc.sh" "grid2.sh" "grid2-shapes.sh" "blocky.sh" "ca.sh")
CURRENT_ALGO_INDEX=0
ALGO_FILE="${ALGO_FILES[$CURRENT_ALGO_INDEX]}"
STATUS_MESSAGE=""
CURRENT_PAGE=0
EVENT_LOG_FILE="engine_events.log" # Define event log file

# --- Global State (Managed by Engine & Algos) ---
declare -gA grid
declare -gA possibilities
declare -gA collapsed
declare -gA rules
declare -ga SYMBOLS
declare -ga PAGES

declare -ga grid_lines_1x1
declare -ga grid_lines_nxn
declare -ga text_lines

declare -g ALGO_TILE_WIDTH=1
declare -g ALGO_TILE_HEIGHT=1

declare -gA TILE_TOPS
declare -gA TILE_BOTS
declare -gA TILE_NAME_TO_CHAR

# --- Logging Function ---
log_event() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$EVENT_LOG_FILE"
}

# --- Cleanup Function (called by trap) ---
cleanup() {
    log_event "Engine exiting"
    tput cnorm # Ensure cursor is visible
    clear      # Clear the screen
    # echo "Goodbye!" # Optional: message to user on exit
}

# --- Trap for cleanup on exit ---
# EXIT trap catches normal exits and signals like INT, TERM
trap cleanup EXIT INT TERM

# --- Helper Function to Load and Initialize Algorithm ---
load_and_init_algorithm() {
    local index=$1

    if [[ -z "${ALGO_FILES[$index]}" ]]; then
        STATUS_MESSAGE="Error: Invalid algorithm index $index"
        echo "ERROR: Invalid algorithm index $index" >&2
        return 1
    fi

    CURRENT_ALGO_INDEX=$index
    ALGO_FILE="${ALGO_FILES[$CURRENT_ALGO_INDEX]}"
    STATUS_MESSAGE="Loading ${ALGO_FILE}..."
    render # Show loading message quickly

    if [[ ! -f "$ALGO_FILE" ]]; then
        STATUS_MESSAGE="Error: Algorithm file not found: $ALGO_FILE"
        echo "ERROR: Algorithm file not found: $ALGO_FILE" >&2
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
    source "$ALGO_FILE"

    # Initialize the new algorithm (assuming functions exist)
    if declare -F init_rules &>/dev/null; then
        init_rules
    else
        echo "WARN: init_rules not found in ${ALGO_FILE}" >&2
    fi

    if declare -F init_grid &>/dev/null; then
        init_grid
    else
         echo "WARN: init_grid not found in ${ALGO_FILE}" >&2
         # Basic grid init if function missing
         for ((y=0; y<ROWS; y++)); do
             for ((x=0; x<COLS; x++)); do
                 collapsed["$y,$x"]=0
             done
         done
    fi

    STATUS_MESSAGE="Loaded ${ALGO_FILE}"
    log_event "Loaded and initialized algorithm: ${ALGO_FILE}"
    return 0
}

# --- Rendering Helper Functions ---

# Function to build the grid lines for the 1x1 character view
_build_grid_lines_1x1() {
    grid_lines_1x1=()
    local error_char="${TILE_NAME_TO_CHAR[ERROR]:-×}"

    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            local key="$row,$col"
            local cell_content="${grid[$key]}"
            local is_collapsed="${collapsed[$key]:-0}"
            local display_char=""

            if [[ "$is_collapsed" == "1" ]]; then
                display_char="$cell_content"

                # Sanity Checks & Corrections
                if [[ -z "$display_char" ]]; then
                    echo "WARN (_build_grid_lines_1x1): Collapsed cell $key has empty grid content! Using '?'. Check algorithm." >&2
                    display_char="?"
                elif [[ "${#display_char}" -gt 1 ]]; then
                    local possibilities_char="${possibilities[$key]}"
                    if [[ "${#possibilities_char}" == 1 ]]; then
                         display_char="$possibilities_char"
                    else
                         echo "WARN (_build_grid_lines_1x1): Collapsed cell $key grid content '${cell_content}' >1 char, and possibilities '${possibilities_char}' not single char. Using error char '$error_char'." >&2
                         display_char="$error_char"
                    fi
                fi

                # Optional: Apply color
                local color_id="${cell_colors[$key]}" # Get color ID if it exists
                if declare -F color_char &>/dev/null && [[ -n "$color_id" ]]; then
                    local fg_color_var="COLOR_${color_id^^}_FG"
                    local bg_color_var="COLOR_${color_id^^}_BG"
                    local fg="${!fg_color_var:-37}" # Default white FG
                    local bg="${!bg_color_var:-40}" # Default black BG

                    if [[ -n "$display_char" ]]; then
                        display_char="$(color_char "$fg" "$bg" "$display_char")"
                    fi
                fi
            else
                # Cell IS NOT collapsed
                # Use space if EMPTY_DISPLAY is on, otherwise dot
                if [[ $EMPTY_DISPLAY -eq 1 ]]; then
                    display_char=" "
                else
                    display_char="·"
                fi
            fi

            # Append the final character to the line
            line+="${display_char}"
        done
        # Add the completed line string to the output array
        grid_lines_1x1+=("$line")
    done
}

# Function to build the grid lines for the NxN tile view
_build_grid_lines_nxn() {
    grid_lines_nxn=()
    local current_error_symbol="${ERROR_SYMBOL:-?}"
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}

    # Check if TILE data is valid
    if ! declare -p TILE_TOPS &>/dev/null || ! declare -p TILE_BOTS &>/dev/null \
           || [[ "$(declare -p TILE_TOPS)" != "declare -A"* ]] || [[ "$(declare -p TILE_BOTS)" != "declare -A"* ]]; then
        echo "ERROR (render_nxn): TILE_TOPS/BOTS arrays not valid or not associative arrays." >&2
        grid_lines_nxn+=("ERROR: Missing or invalid TILE data for NxN rendering")
        return 1
    fi
    if [[ ${#TILE_TOPS[@]} -eq 0 ]]; then
           echo "ERROR (render_nxn): TILE_TOPS array is declared but empty." >&2
           grid_lines_nxn+=("ERROR: TILE_TOPS array is empty")
           return 1
    fi

    # Determine sample glyph width more robustly
    local sample_glyph_width=0
    if [[ -v TILE_TOPS[STRAIGHT_H] ]]; then
        sample_glyph_width=${#TILE_TOPS[STRAIGHT_H]}
    elif [[ ${#TILE_TOPS[@]} -gt 0 ]]; then
        local first_key
        for first_key in "${!TILE_TOPS[@]}"; do break; done # Find first key
        sample_glyph_width=${#TILE_TOPS[$first_key]}
    fi
    # Fallback if width couldn't be determined
    [[ $sample_glyph_width -le 0 ]] && sample_glyph_width=7

    # Define placeholders based on the determined width
    local placeholder_error
    printf -v placeholder_error "%-${sample_glyph_width}.${sample_glyph_width}s" "   ×   "
    local placeholder_unk
    printf -v placeholder_unk "%-${sample_glyph_width}.${sample_glyph_width}s" " ·?·?· "
    local placeholder_uncol
    printf -v placeholder_uncol "%${sample_glyph_width}s" " "

    # Find the area with collapsed cells to determine the "active" region
    local min_x=$COLS
    local max_x=0
    local min_y=$ROWS
    local max_y=0
    local has_collapsed=0
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            if [[ "${collapsed[$key]:-0}" == "1" ]]; then
                has_collapsed=1
                (( y < min_y )) && min_y=$y
                (( y > max_y )) && max_y=$y
                (( x < min_x )) && min_x=$x
                (( x > max_x )) && max_x=$x
            fi
        done
    done

    # Ensure we have some margin around the active area
    if [[ $has_collapsed -eq 1 ]]; then
        (( min_y > 2 )) && min_y=$((min_y - 2))
        (( max_y < ROWS-3 )) && max_y=$((max_y + 2))
        (( min_x > 2 )) && min_x=$((min_x - 2))
        (( max_x < COLS-3 )) && max_x=$((max_x + 2))
    else
        # If nothing collapsed, just show the center area
        min_y=$((ROWS/2 - 5))
        max_y=$((ROWS/2 + 5))
        min_x=$((COLS/2 - 10))
        max_x=$((COLS/2 + 10))
    fi
    # Ensure bounds are valid
    [[ $min_y -lt 0 ]] && min_y=0
    [[ $max_y -ge $ROWS ]] && max_y=$((ROWS-1))
    [[ $min_x -lt 0 ]] && min_x=0
    [[ $max_x -ge $COLS ]] && max_x=$((COLS-1))

    # Only build the active region
    for ((y=min_y; y<=max_y; y++)); do
        for ((ty=0; ty<tile_h; ty++)); do # Loop through tile height (e.g., 0 and 1)
            local current_line=""
            for ((x=min_x; x<=max_x; x++)); do
                local key="$y,$x"
                local glyph_segment=""
                local collapsed_status="${collapsed[$key]:-0}"

                if [[ "$collapsed_status" == "1" ]]; then
                    local tile_name="${grid[$key]:-UNK}"

                    # Check for key existence (optional warning)
                    if ! [[ -v TILE_TOPS["$tile_name"] ]]; then
                         echo "WARN (render_nxn build loop): TILE_TOPS key missing for name '$tile_name'" >&2
                    fi
                    if ! [[ -v TILE_BOTS["$tile_name"] ]]; then
                         echo "WARN (render_nxn build loop): TILE_BOTS key missing for name '$tile_name'" >&2
                    fi

                    # Determine the glyph segment based on tile name and tile row (ty)
                    if [[ "$tile_name" == "$current_error_symbol" ]]; then
                        glyph_segment="$placeholder_error"
                    elif [[ "$tile_name" == "UNK" ]]; then
                        glyph_segment="$placeholder_unk"
                    elif (( ty == 0 )); then # Top part of the tile
                        glyph_segment="${TILE_TOPS[$tile_name]:-$placeholder_unk}"
                    elif (( ty == 1 && tile_h >= 2 )); then # Bottom part (if tile_h >= 2)
                        glyph_segment="${TILE_BOTS[$tile_name]:-$placeholder_unk}"
                    else # Fallback for unexpected ty or tile_h=1 and ty > 0
                        glyph_segment="$placeholder_unk"
                    fi

                    # Ensure the segment has the correct width if found (pad/truncate)
                    if [[ "$glyph_segment" != "$placeholder_unk" && "$glyph_segment" != "$placeholder_error" ]]; then
                         local current_len
                         # Use 'wc -m' for character length if possible, else fallback
                         if command -v wc &> /dev/null && echo "test" | wc -m &> /dev/null; then
                              current_len=$(echo -n "$glyph_segment" | wc -m)
                         else
                              current_len=${#glyph_segment} # Fallback to potentially incorrect byte length
                              if [[ $current_len -ne $sample_glyph_width ]]; then
                                   echo "WARN (render_nxn loop): Using byte length fallback, might be inaccurate for multibyte chars." >&2
                              fi
                         fi

                         local padding_needed=$((sample_glyph_width - current_len))

                         if (( padding_needed > 0 )); then
                             local padding_spaces
                             printf -v padding_spaces "%${padding_needed}s" " " # Create string of spaces
                             glyph_segment+="$padding_spaces" # Append spaces
                         elif (( padding_needed < 0 )); then
                             # Truncate only if wc -m is reliable
                             if command -v wc &> /dev/null && echo "test" | wc -m &> /dev/null; then
                                  glyph_segment="${glyph_segment:0:$sample_glyph_width}" # Truncate based on character count
                                  echo "WARN (render_nxn loop): Glyph too long, truncated to $sample_glyph_width characters." >&2
                             fi
                             # If no reliable wc -m, risk keeping it too long
                         fi
                         # No change if padding_needed is 0
                    fi
                else
                    # Cell is not collapsed
                    glyph_segment="$placeholder_uncol"
                fi

                # Add glyph segment to the current line
                # Add a separator space if this is not the last column in the active region
                if ((x < max_x)); then
                    current_line+="${glyph_segment} "
                else
                    current_line+="${glyph_segment}" # No space after last tile
                fi
            done
            # Add the completed line for this tile-row (ty) to the output array
            grid_lines_nxn+=("$current_line")
        done
    done

    return 0
}

# Function to build the text lines for the side/info panel
_build_text_lines() {
    text_lines=()
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}

    text_lines+=("WFC Engine - $(date +%H:%M:%S)")
    text_lines+=("----------------------------------------")
    text_lines+=("Algorithm: ${ALGO_FILE} [$((CURRENT_ALGO_INDEX+1))/${#ALGO_FILES[@]}] (${tile_w}x${tile_h})")
    text_lines+=("Status: $([[ $RUNNING -eq 1 ]] && echo "Running" || echo "Paused")")
    text_lines+=("Message: $STATUS_MESSAGE")
    text_lines+=("----------------------------------------")

    if [[ ${#PAGES[@]} -gt 0 ]]; then
        text_lines+=("PAGE $((CURRENT_PAGE+1))/${#PAGES[@]}")
        text_lines+=("----------------------------------------")
        local content_lines=()
        IFS=$'\n' read -d '' -ra content_lines <<< "${PAGES[$CURRENT_PAGE]}"
        for line in "${content_lines[@]}"; do
            text_lines+=("$line")
        done
        text_lines+=("----------------------------------------")
    else
        text_lines+=("NO DOC PAGES FOUND")
        text_lines+=("") # Keep spacing consistent
        text_lines+=("----------------------------------------")
    fi

    local collapsed_count=0
    for k in "${!collapsed[@]}"; do
        if [[ "${collapsed[$k]}" == "1" ]]; then
            ((collapsed_count++))
        fi
    done
    text_lines+=("Collapsed: $collapsed_count / $((ROWS*COLS))")
    text_lines+=("----------------------------------------")
    text_lines+=("Controls:")
    text_lines+=("[s] Start/Stop | [c] Step")
    text_lines+=("[n] Next Page  | [p] Prev Page")
    text_lines+=("[1-${#ALGO_FILES[@]}] Select Algorithm | [f] Full Screen | [e] Empty View | [q] Quit")
}

# --- Main Rendering Functions ---

# Renders grid and text panel side-by-side (small mode)
render_small() {
    _build_grid_lines_1x1
    _build_text_lines

    local term_cols
    term_cols=$(tput cols)
    local grid_width=$COLS
    local text_panel_width=40  # Fixed width for right-side panel
    local spacing="   "        # Spacing between grid and panel
    local spacing_width=${#spacing}

    # Determine max number of visible lines from both sections
    local max_lines=${#grid_lines_1x1[@]}
    if (( ${#text_lines[@]} > max_lines )); then
        max_lines=${#text_lines[@]}
    fi

    local output=""
    for ((i = 0; i < max_lines; i++)); do
        local grid_line="${grid_lines_1x1[i]}"
        local text_line="${text_lines[i]}"

        # Fill missing lines with empty strings or pad existing ones
        [[ -z "$grid_line" ]] && grid_line="$(printf "%${grid_width}s" "")"
        [[ -z "$text_line" ]] && text_line=""

        # Format the text panel line (pad/truncate)
        local formatted_text=""
        printf -v formatted_text "%-${text_panel_width}.${text_panel_width}s" "$text_line"

        # Append the combined line to the output buffer
        output+="$grid_line$spacing$formatted_text"$'\n'
    done

    # Print the complete buffer
    printf "%s" "$output"
}

# Renders the grid centered in the terminal (large/full screen mode)
render_large() {
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}
    local buffer=""
    local use_nxn=0

    local grid_display_height=$ROWS
    local grid_char_width=$COLS

    # Determine mode (1x1 or NxN) and build appropriate lines
    if (( tile_w > 1 || tile_h > 1 )); then
        if _build_grid_lines_nxn; then
            # NxN build successful
            if [[ ${#grid_lines_nxn[@]} -gt 0 ]]; then
                grid_display_height=${#grid_lines_nxn[@]}
                # Find the max line width from the actual generated lines
                grid_char_width=0
                for ((i=0; i<${#grid_lines_nxn[@]}; i++)); do
                    local line_len=${#grid_lines_nxn[$i]}
                    (( line_len > grid_char_width )) && grid_char_width=$line_len
                done
            else
                # Fallback if NxN array is empty after build (shouldn't happen if successful)
                grid_display_height=$(( ROWS * tile_h ))
                local estimated_tile_width=8 # 7 glyph + 1 space (approx)
                grid_char_width=$(( (COLS * estimated_tile_width) - 1 )) # subtract 1 for last column no space
            fi
            use_nxn=1
        else
             # NxN build failed, fall back to 1x1
             echo "WARN (render_large): NxN Build FAILED. Falling back to 1x1." >&2
             _build_grid_lines_1x1
             grid_display_height=$ROWS
             grid_char_width=$COLS
             use_nxn=0
        fi
    else
        # Algorithm uses 1x1 tiles
        _build_grid_lines_1x1
        grid_display_height=$ROWS
        grid_char_width=$COLS
        use_nxn=0
    fi

    # Get current terminal dimensions
    local term_rows=$(tput lines)
    local term_cols=$(tput cols)

    # Prevent grid_char_width from exceeding terminal width
    if [[ $grid_char_width -gt $term_cols ]]; then
        grid_char_width=$term_cols
    fi

    # Calculate centering offsets
    local row_offset=$(( (term_rows - grid_display_height) / 2 ))
    local col_offset=$(( (term_cols - grid_char_width) / 2 ))
    [[ $row_offset -lt 0 ]] && row_offset=0
    [[ $col_offset -lt 0 ]] && col_offset=0

    # Start buffer with positioning command
    buffer+=$(printf "\033[$((row_offset + 1));$((col_offset + 1))H")

    # Render lines based on which array type we're using
    if [[ $use_nxn -eq 1 ]]; then
        # --- NxN Array Rendering ---
        if [[ ${#grid_lines_nxn[@]} -eq 0 ]]; then
            buffer+=$(printf "%s" "Error: NxN grid lines array is empty")
        else
            # Determine the final width for padding/truncation on screen
            local display_width=$grid_char_width
            local max_screen_width_for_line=$(( term_cols - col_offset - 1 )) # Available width from offset
             [[ $max_screen_width_for_line -lt 0 ]] && max_screen_width_for_line=0

             # Use the smaller of the grid's calculated width or the available screen width
             if [[ $display_width -gt $max_screen_width_for_line ]]; then
                 display_width=$max_screen_width_for_line
             fi

            for ((i=0; i<${#grid_lines_nxn[@]}; i++)); do
                local line_content="${grid_lines_nxn[$i]}"
                line_content=${line_content//$'\n'/ } # Sanitize potential newlines

                # Pad/truncate the line to the final display_width
                local final_line=""
                printf -v final_line "%-${display_width}.${display_width}s" "$line_content"

                # Add formatted line and positioning for the next line
                buffer+=$(printf "%s\033[$((row_offset + i + 2));$((col_offset + 1))H" "$final_line")
            done
        fi
    else
        # --- 1x1 Array Rendering ---
        if [[ ${#grid_lines_1x1[@]} -eq 0 ]]; then
            buffer+=$(printf "%s" "Error: 1x1 grid lines array is empty")
        else
            for ((i=0; i<${#grid_lines_1x1[@]}; i++)); do
                local line_content="${grid_lines_1x1[$i]}"
                line_content=${line_content//$'\n'/ } # Sanitize

                # Add the line content and positioning for the next line
                # No extra padding/truncation here, assumes 1 char per grid cell
                buffer+=$(printf "%s\033[$((row_offset + i + 2));$((col_offset + 1))H" "$line_content")
            done
        fi
    fi

    # Print the complete buffer with all positioned lines
    printf "%s" "$buffer"
}

# --- Main Render Dispatcher ---
render() {
    local output_buffer=""

    # Call the appropriate render function based on mode
    if [[ $FULL_SCREEN -eq 1 ]]; then
        output_buffer=$(render_large) # Capture output from function
    else
        output_buffer=$(render_small) # Capture output from function
    fi

    # Clear screen THEN print the entire buffer at once
    # Use %b to interpret potential \n sequences from render_small
    printf "\033[H\033[J%b" "$output_buffer"
}

# --- Main Application Loop ---
main() {
    log_event "Engine started"

    # Initial load of the default algorithm
    load_and_init_algorithm $CURRENT_ALGO_INDEX
    if [[ $? -ne 0 ]]; then
        echo "Error loading initial algorithm ${ALGO_FILES[$CURRENT_ALGO_INDEX]}. Exiting." >&2
        # Trap will handle cleanup
        exit 1
    fi

    # Setup terminal
    tput civis # Hide cursor

    # Main loop
    while [[ $SHOULD_EXIT -eq 0 ]]; do

        local key_pressed=0 # Flag to check if input requiring render was received this cycle

        # Process algorithm step if running
        if [[ $RUNNING -eq 1 ]]; then
            if declare -F update_algorithm &>/dev/null; then
                update_algorithm # Algorithm modifies STATUS_MESSAGE etc.
                local exit_code=$?
                # Stop running if algorithm returns non-zero (e.g., finished, error)
                if [[ $exit_code -ne 0 ]]; then
                     RUNNING=0
                     log_event "Algorithm ${ALGO_FILE} finished or signaled stop (code $exit_code). Pausing."
                fi
            else
                 STATUS_MESSAGE="Error: update_algorithm not found in ${ALGO_FILE}"
                 echo "ERROR: update_algorithm not found in ${ALGO_FILE}" >&2
                 RUNNING=0 # Stop if function missing
            fi
            # Render immediately after processing when running
            render
        fi # End if running

        # Check for user input (short timeout for responsiveness)
        read -s -n 1 -t 0.01 key
        if [[ -n "$key" ]]; then
             key_pressed=1 # Mark that input was received

             case "$key" in
                 [1-9]) # Handle number input for algorithm selection
                      local selected_index=$((key - 1)) # Convert key '1' to index 0, etc.
                      if [[ "$selected_index" -lt "${#ALGO_FILES[@]}" && "$selected_index" -ne "$CURRENT_ALGO_INDEX" ]]; then
                          # Valid index and different from current
                          load_and_init_algorithm "$selected_index"
                          # Re-render needed after loading new algo (handled below if paused)
                      elif [[ "$selected_index" -ge "${#ALGO_FILES[@]}" ]]; then
                          # Invalid index (too high)
                          STATUS_MESSAGE="Invalid algorithm number: $key"
                          echo "WARN (input): Invalid algorithm number $key" >&2
                          # Re-render needed to show status message
                      else
                          # Same algorithm selected or other issue
                          key_pressed=0 # No change occurred, don't re-render if paused
                      fi
                      ;;

                 s) # Start/Stop
                      RUNNING=$((1-RUNNING))
                      if [[ $RUNNING -eq 1 ]]; then
                           STATUS_MESSAGE="Running..."
                      else
                           STATUS_MESSAGE="Paused"
                      fi
                      log_event "Toggled running state to $RUNNING"
                      # Re-render needed to show status update
                      ;;

                 c) # Step (Collapse One)
                      if declare -F update_algorithm > /dev/null; then
                          if [[ $RUNNING -eq 0 ]]; then # Only allow step if paused
                              log_event "Manual step requested for ${ALGO_FILE}"
                              update_algorithm
                              local exit_code=$?
                              if [[ $exit_code -ne 0 ]]; then
                                  RUNNING=0 # Keep paused if it finishes/errors
                                  log_event "Manual step finished for ${ALGO_FILE}, algorithm signaled stop (code $exit_code)"
                              else
                                   log_event "Manual step finished for ${ALGO_FILE} (code $exit_code)"
                              fi
                              # Re-render needed after step
                          else
                              STATUS_MESSAGE="Pause ([s]) before stepping ([c])"
                              # Re-render needed to show status message
                          fi
                      else
                          STATUS_MESSAGE="Error: update_algorithm not found"
                          echo "ERROR: update_algorithm not found (manual step)" >&2
                          # Re-render needed to show error
                      fi
                      ;;

                 n) # Next Page
                      if [[ ${#PAGES[@]} -gt 0 ]]; then
                          local old_page=$CURRENT_PAGE
                          CURRENT_PAGE=$(( (CURRENT_PAGE + 1) % ${#PAGES[@]} ))
                          if [[ $old_page != $CURRENT_PAGE ]]; then
                              STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                              log_event "Changed to page $CURRENT_PAGE"
                              # Re-initialize grid if needed by specific algorithms
                              if [[ "$ALGO_FILE" == "ca.sh" || "$ALGO_FILE" == "grid2-shapes.sh" ]] && declare -F init_grid &>/dev/null; then
                                   log_event "Re-initializing $ALGO_FILE grid for new page $CURRENT_PAGE"
                                   init_grid # Call init_grid, it reads global CURRENT_PAGE
                              fi
                          else
                              key_pressed=0 # Page didn't change (e.g., only 1 page)
                          fi
                      else
                          STATUS_MESSAGE="No pages available"
                          # Re-render needed to show status
                      fi
                      ;;

                 p) # Previous Page
                       if [[ ${#PAGES[@]} -gt 0 ]]; then
                          local old_page=$CURRENT_PAGE
                          CURRENT_PAGE=$(( (CURRENT_PAGE - 1 + ${#PAGES[@]}) % ${#PAGES[@]} ))
                          if [[ $old_page != $CURRENT_PAGE ]]; then
                              STATUS_MESSAGE="Page $((CURRENT_PAGE+1))/${#PAGES[@]}"
                              log_event "Changed to page $CURRENT_PAGE"
                              # Re-initialize grid if needed by specific algorithms
                              if [[ "$ALGO_FILE" == "ca.sh" || "$ALGO_FILE" == "grid2-shapes.sh" ]] && declare -F init_grid &>/dev/null; then
                                   log_event "Re-initializing $ALGO_FILE grid for new page $CURRENT_PAGE"
                                   init_grid # Call init_grid, it reads global CURRENT_PAGE
                              fi
                          else
                              key_pressed=0 # Page didn't change
                          fi
                      else
                          STATUS_MESSAGE="No pages available"
                          # Re-render needed to show status
                      fi
                      ;;

                 q) # Quit
                      log_event "Quit key pressed."
                      SHOULD_EXIT=1
                      key_pressed=1 # Ensure render happens if paused? Not really needed, trap handles exit.
                      ;;

                 f) # Toggle full screen mode
                      FULL_SCREEN=$((1-FULL_SCREEN))
                      STATUS_MESSAGE="Full screen mode: $([[ $FULL_SCREEN -eq 1 ]] && echo "ON" || echo "OFF")"
                      log_event "Toggled full screen mode to $FULL_SCREEN"
                      ;;

                 e) # Toggle empty display mode
                      EMPTY_DISPLAY=$((1-EMPTY_DISPLAY))
                      STATUS_MESSAGE="Empty display mode: $([[ $EMPTY_DISPLAY -eq 1 ]] && echo "ON" || echo "OFF")"
                      log_event "Toggled empty display mode to $EMPTY_DISPLAY"
                      ;;

                 r) # Generate report (kept functionality)
                      log_event "Generating charset and color report."
                      generate_charset_and_color_report > charset_color_report.txt
                      STATUS_MESSAGE="Charset and color report saved to charset_color_report.txt"
                      ;;

                 *) # Unrecognized key
                      key_pressed=0 # Don't re-render if paused
                      ;;
             esac
        fi # End if key pressed

        # Only render when paused IF a valid key was pressed and processed
        if [[ $RUNNING -eq 0 && $key_pressed -eq 1 ]]; then
             render
        fi

        # Loop exit condition check (redundant due to while condition, but explicit)
        if [[ $SHOULD_EXIT -eq 1 ]]; then
            break
        fi

        # If paused and no key was pressed, the loop naturally continues
        # after the read timeout without processing or rendering.

    done # End main loop

    # Cleanup is handled by the trap on EXIT
}

# Optional: Function to generate report
generate_charset_and_color_report() {
    echo "Charset and Color Report"
    echo "------------------------"

    declare -A unique_symbols
    for value in "${grid[@]}"; do
        unique_symbols["$value"]=1
    done

    echo "Symbols used:"
    for symbol in "${!unique_symbols[@]}"; do
        echo -e "'$symbol'"
    done
    echo "" # Add spacing

    declare -A unique_colors
    # Assuming cell_colors might be defined by algorithms
    if declare -p cell_colors &>/dev/null && [[ "$(declare -p cell_colors)" == "declare -A"* ]]; then
        for color in "${cell_colors[@]}"; do
            unique_colors["$color"]=1
        done

        echo "Colors used:"
        for color_id in "${!unique_colors[@]}"; do
            # Attempt to use color_char if available
            if declare -F color_char &> /dev/null; then
                 local fg_var="COLOR_${color_id^^}_FG"
                 local bg_var="COLOR_${color_id^^}_BG"
                 local fg_val="${!fg_var:-?}" # Get FG value or ?
                 local bg_val="${!bg_var:-?}" # Get BG value or ?

                 if [[ "$fg_val" != "?" && "$bg_val" != "?" ]]; then
                      echo -e "$(color_char "$fg_val" "$bg_val" " $color_id ") (FG:$fg_val BG:$bg_val)"
                 else
                      echo "Color ID: $color_id (Variable mapping COLOR_${color_id^^}_FG/BG not found)"
                 fi
            else
                 echo "Color ID: $color_id ('color_char' function not available)"
            fi
        done
    else
         echo "Color information (cell_colors map) not available."
    fi
}

# --- Start the engine ---
main
