#!/usr/bin/env bash
export LC_ALL=C.UTF-8 # Ensure UTF-8 locale

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8
# Rest of your engine script...

# Simple engine that loads and runs algorithm files

# --- Configuration ---
ROWS=15
COLS=30
RUNNING=0           # Start paused
SHOULD_EXIT=0       # Exit flag
FULL_SCREEN=0       # Toggle for full screen mode
EMPTY_DISPLAY=0     # Toggle for replacing dots with spaces
# Define available algorithms
declare -a ALGO_FILES=("snake.sh" "wfc-basic.sh" "wfc.sh" "grid2.sh" "grid2-shapes.sh" "blocky.sh" "ca.sh")
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
    grid_lines_1x1=()
    echo "DEBUG (_build_grid_lines_1x1): Building grid lines for 1x1 display." >> "$DEBUG_LOG_FILE"
    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            local key="$row,$col"
            local cell_char="${grid[$key]}"
            local display_char="$cell_char"
            # Handle uninitialized or empty cells
            if [[ -z "$cell_char" ]] || [[ "$cell_char" == ' ' ]]; then
                display_char="·"  # Placeholder for uncollapsed cells
            else
                # Apply colors if the cell is collapsed and colors are defined
                local color_id="${cell_colors[$key]}"
                if declare -F color_char &>/dev/null && [[ -n "$color_id" ]]; then
                    if [[ "$color_id" == "1" ]]; then
                        display_char="$(color_char "$COLOR1_FG" "$COLOR1_BG" "$cell_char")"
                    elif [[ "$color_id" == "2" ]]; then
                        display_char="$(color_char "$COLOR2_FG" "$COLOR2_BG" "$cell_char")"
                    else
                        # Default to no color if color_id is unexpected
                        display_char="$cell_char"
                    fi
                fi
            fi
            line+="$display_char"
        done
        grid_lines_1x1+=("$line")
    done
}

_build_grid_lines_nxn() {
    grid_lines_nxn=() # Clear global array
    local current_error_symbol="${ERROR_SYMBOL:-?}"
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}

    # Check if TILE data is valid
    if ! declare -p TILE_TOPS &>/dev/null || ! declare -p TILE_BOTS &>/dev/null \
           || [[ "$(declare -p TILE_TOPS)" != "declare -A"* ]] || [[ "$(declare -p TILE_BOTS)" != "declare -A"* ]]; then
        echo "ERROR (render_nxn): TILE_TOPS/BOTS arrays not valid or not associative arrays." >> "$DEBUG_LOG_FILE"
        grid_lines_nxn+=("ERROR: Missing or invalid TILE data for NxN rendering") # Add specific error line
        return 1 # Indicate failure
    fi
    # Check if TILE_TOPS is empty - indicates an issue even if declared
    if [[ ${#TILE_TOPS[@]} -eq 0 ]]; then
         echo "ERROR (render_nxn): TILE_TOPS array is declared but empty." >> "$DEBUG_LOG_FILE"
         grid_lines_nxn+=("ERROR: TILE_TOPS array is empty")
         return 1
    fi

    # Determine sample glyph width more robustly
    local sample_glyph_width=0
    if [[ -v TILE_TOPS[STRAIGHT_H] ]]; then
        sample_glyph_width=${#TILE_TOPS[STRAIGHT_H]}
    elif [[ ${#TILE_TOPS[@]} -gt 0 ]]; then
        local first_key
        for first_key in "${!TILE_TOPS[@]}"; do break; done
        sample_glyph_width=${#TILE_TOPS[$first_key]}
    fi
    # Fallback if width couldn't be determined
    [[ $sample_glyph_width -le 0 ]] && sample_glyph_width=7

    echo "DEBUG (render_nxn): Building ${tile_w}x${tile_h} lines (using sample_glyph_width=${sample_glyph_width})..." >> "$DEBUG_LOG_FILE"

    # Define placeholders based on the determined width
    local placeholder_error; printf -v placeholder_error "%-${sample_glyph_width}.${sample_glyph_width}s" "   ×   "
    local placeholder_unk; printf -v placeholder_unk "%-${sample_glyph_width}.${sample_glyph_width}s" " ·?·?· "
    local placeholder_uncol; printf -v placeholder_uncol "%${sample_glyph_width}s" " " 

    # Find the area with collapsed cells to determine the "active" region
    local min_x=$COLS local max_x=0 local min_y=$ROWS local max_y=0
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
        min_y=$((ROWS/2 - 5)); max_y=$((ROWS/2 + 5))
        min_x=$((COLS/2 - 10)); max_x=$((COLS/2 + 10))
    fi
    # Ensure bounds are valid
    [[ $min_y -lt 0 ]] && min_y=0; [[ $max_y -ge $ROWS ]] && max_y=$((ROWS-1))
    [[ $min_x -lt 0 ]] && min_x=0; [[ $max_x -ge $COLS ]] && max_x=$((COLS-1))

    echo "DEBUG (render_nxn): Active region: (${min_x},${min_y}) to (${max_x},${max_y})" >> "$DEBUG_LOG_FILE"
    
    # Only build the active region
    for ((y=min_y; y<=max_y; y++)); do
        for ((ty=0; ty<tile_h; ty++)); do # Loop through tile height (0 and 1)
            local current_line=""
            for ((x=min_x; x<=max_x; x++)); do
                local key="$y,$x"; local glyph_segment=""; local collapsed_status="${collapsed[$key]:-0}"
                
                # --- ADD LOGGING FOR ty ---
                echo "DEBUG (render_nxn build loop): Processing y=$y, x=$x, ty=$ty" >> "$DEBUG_LOG_FILE"
                
                if [[ "$collapsed_status" == "1" ]]; then
                    local tile_name="${grid[$key]:-UNK}"
                    echo "DEBUG (render_nxn build loop): Collapsed cell $key, Name='$tile_name'" >> "$DEBUG_LOG_FILE"

                    # --- ADD CHECK FOR KEY EXISTENCE ---
                    if ! [[ -v TILE_TOPS["$tile_name"] ]]; then
                         echo "WARN (render_nxn build loop): TILE_TOPS key missing for name '$tile_name'" >> "$DEBUG_LOG_FILE"
                    fi
                    if ! [[ -v TILE_BOTS["$tile_name"] ]]; then
                         echo "WARN (render_nxn build loop): TILE_BOTS key missing for name '$tile_name'" >> "$DEBUG_LOG_FILE"
                    fi
                    # --- END CHECK ---

                    if [[ "$tile_name" == "$current_error_symbol" ]]; then glyph_segment="$placeholder_error"
                    elif [[ "$tile_name" == "UNK" ]]; then glyph_segment="$placeholder_unk"
                    elif (( ty == 0 )); then # Top part of the tile
                        glyph_segment="${TILE_TOPS[$tile_name]:-$placeholder_unk}"
                        echo "DEBUG (render_nxn build loop): Fetched TOP glyph: '$glyph_segment'" >> "$DEBUG_LOG_FILE"
                    elif (( ty == 1 && tile_h >= 2 )); then # Bottom part
                        glyph_segment="${TILE_BOTS[$tile_name]:-$placeholder_unk}"
                        # --- LOG BOTTOM GLYPH FETCH ---
                        echo "DEBUG (render_nxn build loop): Fetched BOT glyph: '$glyph_segment'" >> "$DEBUG_LOG_FILE"
                    else 
                        glyph_segment="$placeholder_unk"
                        echo "DEBUG (render_nxn build loop): Using UNK placeholder (ty=$ty, tile_h=$tile_h)" >> "$DEBUG_LOG_FILE"
                    fi
                    
                    # Ensure the segment has the correct width if found
                    if [[ "$glyph_segment" != "$placeholder_unk" && "$glyph_segment" != "$placeholder_error" ]]; then
                         # --- Modify Padding Here ---
                         local current_len # Use 'wc -m' for character length if possible, else fallback
                         # Check if wc command exists and supports -m flag for character count
                         if command -v wc &> /dev/null && echo "test" | wc -m &> /dev/null; then
                             current_len=$(echo -n "$glyph_segment" | wc -m)
                         else 
                             current_len=${#glyph_segment} # Fallback to potentially incorrect byte length
                             if [[ $current_len -ne $sample_glyph_width ]]; then 
                                echo "WARN (render_nxn loop): Using byte length fallback, might be inaccurate for multibyte chars." >> "$DEBUG_LOG_FILE"
                             fi
                         fi
                         
                         local padding_needed=$((sample_glyph_width - current_len))
                         
                         echo "DEBUG (render_nxn loop): key=$key, tile_name='$tile_name', ty=$ty, sample_glyph_width=$sample_glyph_width, current_len=$current_len, padding_needed=$padding_needed, BEFORE PADDING glyph_segment='${glyph_segment}'" >> "$DEBUG_LOG_FILE"

                         if (( padding_needed > 0 )); then
                             local padding_spaces
                             printf -v padding_spaces "%${padding_needed}s" " " # Create string of spaces
                             glyph_segment+="$padding_spaces" # Append spaces
                         elif (( padding_needed < 0 )); then 
                             # If wc -m worked, truncation is needed, otherwise this might be wrong
                             # For simplicity now, let's avoid truncation unless wc -m is reliable
                             if command -v wc &> /dev/null && echo "test" | wc -m &> /dev/null; then
                                 glyph_segment="${glyph_segment:0:$sample_glyph_width}" # Truncate based on character count (requires UTF-8 locale)
                                 echo "WARN (render_nxn loop): Glyph too long, truncated to $sample_glyph_width characters." >> "$DEBUG_LOG_FILE"
                             fi
                             # If no reliable wc -m, we risk keeping it too long if glyph definition is wrong
                         fi
                         # No change if padding_needed is 0
                         
                         echo "DEBUG (render_nxn loop): key=$key, tile_name='$tile_name', ty=$ty, AFTER PADDING glyph_segment='${glyph_segment}'" >> "$DEBUG_LOG_FILE"
                         # --- End Padding Modification ---
                    fi
                else
                    glyph_segment="$placeholder_uncol" 
                fi
                
                # Only add a separator if this is not the last column
                if ((x < max_x)); then
                    current_line+="${glyph_segment} " # Add space after non-last tiles
                else
                    current_line+="${glyph_segment}" # No space after last tile
                fi

                # Add logging when grid2-shapes.sh is active and cell is collapsed
                if [[ "$ALGO_FILE" == "grid2-shapes.sh" && "$collapsed_status" == "1" ]]; then
                    local top_glyph="${TILE_TOPS[$tile_name]:-MISSING}"
                    local bot_glyph="${TILE_BOTS[$tile_name]:-MISSING}"
                    echo "DEBUG (render_nxn shapes): key=$key, name='$tile_name', top='$top_glyph', bot='$bot_glyph', final_segment='$glyph_segment'" >> "$DEBUG_LOG_FILE"
                fi
            done
            # --- LOG FINAL LINE FOR THIS TILE ROW ---
            echo "DEBUG (render_nxn build loop): Adding line for ty=$ty: '$current_line'" >> "$DEBUG_LOG_FILE"
            grid_lines_nxn+=("$current_line") 
        done
    done
    
    echo "DEBUG (render_nxn): Built ${#grid_lines_nxn[@]} lines for active region" >> "$DEBUG_LOG_FILE"
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

    echo "DEBUG (render): Using SIDE-BY-SIDE mode." >> "$DEBUG_LOG_FILE"
    local term_cols=$(tput cols)
    local desired_text_width=40
    local panel_spacing_str="   " # 3 spaces

    # Calculate available width for the text panel
    local max_text_width=$(( term_cols - COLS - ${#panel_spacing_str} ))
    [[ $max_text_width -lt 0 ]] && max_text_width=0
    local actual_text_width=$(( desired_text_width < max_text_width ? desired_text_width : max_text_width ))
    [[ $actual_text_width -lt 0 ]] && actual_text_width=0

    local max_rows=$(( ${#grid_lines_1x1[@]} > ${#text_lines[@]} ? ${#grid_lines_1x1[@]} : ${#text_lines[@]} ))

    for ((i=0; i<max_rows; i++)); do
        local line_str="${grid_lines_1x1[$i]}${panel_spacing_str}${text_lines[$i]:0:$actual_text_width}"
        printf "%b\n" "$line_str"
    done
}

render_large() { # Full screen mode
    local tile_w=${ALGO_TILE_WIDTH:-1}
    local tile_h=${ALGO_TILE_HEIGHT:-1}
    local buffer=""
    local use_nxn=0

    echo "DEBUG (render_large): Using FULL SCREEN mode. Algo Tile Size: ${tile_w}x${tile_h}" >> "$DEBUG_LOG_FILE"
    local grid_display_height=$ROWS
    local grid_char_width=$COLS

    # Determine mode and build lines
    if (( tile_w > 1 || tile_h > 1 )); then
        if _build_grid_lines_nxn; then
            echo "DEBUG (render_large): NxN Build SUCCESS. Will use grid_lines_nxn directly." >> "$DEBUG_LOG_FILE"
            
            # Get the dimensions from the actual array
            if [[ ${#grid_lines_nxn[@]} -gt 0 ]]; then
                grid_display_height=${#grid_lines_nxn[@]}
                # Find the max line width from the actual lines
                grid_char_width=0
                for ((i=0; i<${#grid_lines_nxn[@]}; i++)); do
                    local line_len=${#grid_lines_nxn[$i]}
                    (( line_len > grid_char_width )) && grid_char_width=$line_len
                done
            else
                grid_display_height=$(( ROWS * tile_h ))
                local estimated_tile_width=8 # 7 for glyph + 1 for space
                grid_char_width=$(( (COLS * estimated_tile_width) - 1 )) # subtract 1 for last column no space
            fi
            
            echo "DEBUG (render_large): Actual NxN grid dimensions: ${grid_char_width}w x ${grid_display_height}h" >> "$DEBUG_LOG_FILE"
            use_nxn=1
        else
             echo "WARN (render_large): NxN Build FAILED. Falling back to 1x1." >> "$DEBUG_LOG_FILE"
             _build_grid_lines_1x1
             grid_display_height=$ROWS
             grid_char_width=$COLS
             use_nxn=0
        fi
    else
        _build_grid_lines_1x1
        echo "DEBUG (render_large): Using 1x1 lines for full screen." >> "$DEBUG_LOG_FILE"
        grid_display_height=$ROWS
        grid_char_width=$COLS
        use_nxn=0
    fi

    # Get current terminal dimensions
    local term_rows=$(tput lines)
    local term_cols=$(tput cols)
    
    # Prevent grid_char_width from exceeding terminal width
    if [[ $grid_char_width -gt $term_cols ]]; then
        echo "DEBUG (render_large): Truncating grid width to fit terminal (${grid_char_width} -> ${term_cols})" >> "$DEBUG_LOG_FILE"
        grid_char_width=$term_cols
    fi
    
    local row_offset=$(( (term_rows - grid_display_height) / 2 ))
    local col_offset=$(( (term_cols - grid_char_width) / 2 ))
    [[ $row_offset -lt 0 ]] && row_offset=0
    [[ $col_offset -lt 0 ]] && col_offset=0
    
    echo "DEBUG (render_large): Centering calculation: Terminal=${term_cols}x${term_rows}, Grid=${grid_char_width}x${grid_display_height}, Offset=${col_offset}x${row_offset}" >> "$DEBUG_LOG_FILE"

    # Build the output buffer - START at offset position
    buffer+=$(printf "\033[$((row_offset + 1));$((col_offset + 1))H")

    # Render lines based on which array type we're using
    if [[ $use_nxn -eq 1 ]]; then
        # --- NxN Array Rendering ---
        echo "DEBUG (render_large): Rendering NxN grid with ${#grid_lines_nxn[@]} lines" >> "$DEBUG_LOG_FILE"
        if [[ ${#grid_lines_nxn[@]} -eq 0 ]]; then
            buffer+=$(printf "%s" "Error: NxN grid lines array is empty")
        else
            # Max width available on screen for this centered block
            # This is the effective width we want to pad/truncate to.
            local display_width=$grid_char_width 
            local max_screen_width_for_line=$(( term_cols - col_offset -1 ))
             [[ $max_screen_width_for_line -lt 0 ]] && max_screen_width_for_line=0
             
            # Use the smaller of the grid's calculated width or the available screen width
             if [[ $display_width -gt $max_screen_width_for_line ]]; then
                 display_width=$max_screen_width_for_line
             fi
             echo "DEBUG (render_large NxN loop): Final display_width for padding/truncation: $display_width" >> "$DEBUG_LOG_FILE"


            for ((i=0; i<${#grid_lines_nxn[@]}; i++)); do
                local line_content="${grid_lines_nxn[$i]}"
                line_content=${line_content//$'\n'/ } # Sanitize

                # --- LOG LINE BEING RENDERED ---
                echo "DEBUG (render_large NxN render loop): Rendering line i=$i: '$line_content'" >> "$DEBUG_LOG_FILE"

                # Pad/truncate the line to the final display_width
                local final_line=""
                printf -v final_line "%-${display_width}.${display_width}s" "$line_content"

                buffer+=$(printf "%s\033[$((row_offset + i + 2));$((col_offset + 1))H" "$final_line")
            done
        fi
    else
        # --- 1x1 Array Rendering ---
        echo "DEBUG (render_large): Rendering 1x1 grid with ${#grid_lines_1x1[@]} lines" >> "$DEBUG_LOG_FILE"
        if [[ ${#grid_lines_1x1[@]} -eq 0 ]]; then
            buffer+=$(printf "%s" "Error: 1x1 grid lines array is empty")
        else
            for ((i=0; i<${#grid_lines_1x1[@]}; i++)); do
                # DIRECTLY access the 1x1 array, no nameref
                local line_content="${grid_lines_1x1[$i]}"
                # Sanitize and use without padding
                line_content=${line_content//$'\n'/ }
                
                # Add the line content and position for next line
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
                            # ADD CHECK FOR grid2-shapes.sh HERE
                            if [[ "$ALGO_FILE" == "ca.sh" || "$ALGO_FILE" == "grid2-shapes.sh" ]] && declare -F init_grid &>/dev/null; then
                                echo "DEBUG (input): Re-initializing $ALGO_FILE grid for new page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                                init_grid # Call init_grid, it reads global CURRENT_PAGE
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
                            # ADD CHECK FOR grid2-shapes.sh HERE
                            if [[ "$ALGO_FILE" == "ca.sh" || "$ALGO_FILE" == "grid2-shapes.sh" ]] && declare -F init_grid &>/dev/null; then
                                echo "DEBUG (input): Re-initializing $ALGO_FILE grid for new page $CURRENT_PAGE" >> "$DEBUG_LOG_FILE"
                                init_grid # Call init_grid, it reads global CURRENT_PAGE
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

