# Engine Rendering Logic

# --- Internal Rendering Data Builders ---

# Builds 1x1 ASCII view based on Base Grid state into global 'display_lines'
_build_ascii_1x1() {
    display_lines=() # Clear/initialize output array
    local default_char="?" # Fallback for empty grid cells

    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            local key="$row,$col"
            local is_collapsed="${collapsed[$key]:-0}"
            local display_char=""

            if [[ "$is_collapsed" == "1" ]]; then
                # Use grid content or default for collapsed
                display_char="${grid[$key]:-$default_char}"
                 # Ensure single character if possible (handle algo errors)
                 if [[ "${#display_char}" -gt 1 ]]; then display_char="?"; fi
            else
                # Uncollapsed cell: Use space or dot
                if [[ $EMPTY_DISPLAY -eq 1 ]]; then
                    display_char=" "
                else
                    display_char="·"
                fi
            fi
            line+="${display_char}"
        done
        display_lines+=("$line") # Add line of exactly COLS characters
    done
    return 0
}

# Builds 1x1 Enhanced view using algorithm's get_enhanced_char into global 'display_lines'
_build_enhanced_1x1() {
    display_lines=() # Clear/initialize output array

    if ! declare -F get_enhanced_char &>/dev/null; then
        display_lines+=("Error: Algorithm ${ALGO_FILE}")
        display_lines+=("does not provide get_enhanced_char()")
        display_lines+=("Cannot render Enhanced format.")
        return 1
    fi

    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            local key="$row,$col"
            local collapse_status="${collapsed[$key]:-0}"
            local grid_val="${grid[$key]:-}" # Pass empty string if not set

            # Call the algorithm's function to get the character (may include ANSI codes)
            local display_char
            display_char=$(get_enhanced_char "$row" "$col" "$collapse_status" "$grid_val")
            line+="${display_char}" # Append potentially multi-byte/ANSI string
        done
        display_lines+=("$line")
    done
    return 0
}

# Builds NxN Tiled view using pre-loaded tile data into global 'display_lines'
_build_tiled_nxn() {
    display_lines=() # Clear/initialize output array

    # Check if required data was loaded
    if [[ -z "${TILED_RENDER_DATA[tile_width]}" || -z "${TILED_RENDER_DATA[TILE_TOPS_str]}" || -z "${TILED_RENDER_DATA[TILE_BOTS_str]}" ]]; then
        display_lines+=("Error: Tiled render format selected,")
        display_lines+=("but required tile data is missing.")
        display_lines+=("(Check algorithm's get_tiled_data() function)")
        return 1
    fi

    # Extract data stored during loading
    local tile_w=${TILED_RENDER_DATA[tile_width]}
    local tile_h=${TILED_RENDER_DATA[tile_height]:-1}
    local error_symbol="${TILED_RENDER_DATA[error_symbol]:-?}"
    local -A TILE_TOPS_local
    local -A TILE_BOTS_local

    # Safely deserialize TILE data
    eval "${TILED_RENDER_DATA[TILE_TOPS_str]/declare -A/TILE_TOPS_local=}" || { display_lines+=("Error: Failed parsing TILE_TOPS data"); return 1; }
    eval "${TILED_RENDER_DATA[TILE_BOTS_str]/declare -A/TILE_BOTS_local=}" || { display_lines+=("Error: Failed parsing TILE_BOTS data"); return 1; }

    if [[ ${#TILE_TOPS_local[@]} -eq 0 ]]; then
        display_lines+=("Error: TILE_TOPS data is empty.")
        return 1
    fi

    # Determine glyph width from tile data
    local sample_glyph_width=0
    local k
    for k in "${!TILE_TOPS_local[@]}"; do sample_glyph_width=${#TILE_TOPS_local[$k]}; break; done
    [[ $sample_glyph_width -le 0 ]] && sample_glyph_width=7 # Fallback

    # Define placeholders
    local placeholder_error; printf -v placeholder_error "%-${sample_glyph_width}.${sample_glyph_width}s" "   ×   "
    local placeholder_unk; printf -v placeholder_unk "%-${sample_glyph_width}.${sample_glyph_width}s" " ·?·?· "
    local placeholder_uncol; printf -v placeholder_uncol "%${sample_glyph_width}s" " "

    # Render loop for tiles
    for ((y=0; y<ROWS; y++)); do
        for ((ty=0; ty<tile_h; ty++)); do # Loop through tile height (e.g., 0=top, 1=bottom)
            local current_line=""
            for ((x=0; x<COLS; x++)); do
                local key="$y,$x"
                local glyph_segment=""
                local collapsed_status="${collapsed[$key]:-0}"

                if [[ "$collapsed_status" == "1" ]]; then
                    local tile_name="${grid[$key]:-UNK}"
                    if [[ "$tile_name" == "$error_symbol" ]]; then glyph_segment="$placeholder_error"
                    elif [[ "$tile_name" == "UNK" ]]; then glyph_segment="$placeholder_unk"
                    elif (( ty == 0 )); then glyph_segment="${TILE_TOPS_local[$tile_name]:-$placeholder_unk}"
                    elif (( ty == 1 && tile_h >= 2 )); then glyph_segment="${TILE_BOTS_local[$tile_name]:-$placeholder_unk}"
                    else glyph_segment="$placeholder_unk"; fi # Fallback

                    # Pad/truncate segment if needed (basic length check)
                    if [[ "$glyph_segment" != "$placeholder_unk" && "$glyph_segment" != "$placeholder_error" ]]; then
                         local current_len=${#glyph_segment} # Note: may be inaccurate for visual width
                         local padding_needed=$((sample_glyph_width - current_len))
                         if (( padding_needed > 0 )); then
                             local pad; printf -v pad "%${padding_needed}s"; glyph_segment+="$pad"
                         elif (( padding_needed < 0 )); then
                             glyph_segment="${glyph_segment:0:$sample_glyph_width}"
                         fi
                    fi
                else # Not collapsed
                    glyph_segment="$placeholder_uncol"
                fi
                current_line+="${glyph_segment}"
                ((x < COLS - 1)) && current_line+=" " # Add space between tiles
            done # End columns (x)
            display_lines+=("$current_line")
        done # End tile rows (ty)
    done # End grid rows (y)
    return 0
}

# --- Central Display Lines Builder ---
# Calls the appropriate build function based on format, populates global 'display_lines'
# Primarily used by render_large.
_build_display_lines() {
    case "$CURRENT_RENDER_FORMAT" in
        "ASCII")    _build_ascii_1x1 ;;
        "ENHANCED") _build_enhanced_1x1 ;;
        "TILED")    _build_tiled_nxn ;;
        *)
            display_lines=() # Clear
            display_lines+=("Error: Unknown render format '$CURRENT_RENDER_FORMAT'")
            return 1
            ;;
    esac
    return $? # Return status of the build function
}

# --- Info Panel Builder ---
# Builds text lines for the info panel into global 'text_lines'
# Primarily used by render_small.
_build_text_lines() {
    text_lines=() # Clear/initialize global array

    local available_str=""
    [[ -v AVAILABLE_FORMATS[ASCII] ]] && available_str+="A"
    [[ -v AVAILABLE_FORMATS[ENHANCED] ]] && available_str+="E"
    [[ -v AVAILABLE_FORMATS[TILED] ]] && available_str+="T"

    text_lines+=("WFC Engine - $(date +"%T")")
    text_lines+=("----------------------------------------")
    text_lines+=("Algorithm: ${ALGO_FILE} [$((CURRENT_ALGO_INDEX+1))/${#ALGO_FILES[@]}]")
    text_lines+=("Format: ${CURRENT_RENDER_FORMAT} [$available_str]")
    local status_str="Paused"
    [[ $RUNNING -eq 1 ]] && status_str="Running"
    text_lines+=("Status: $status_str")
    text_lines+=("Message: $STATUS_MESSAGE")
    text_lines+=("----------------------------------------")

    # Doc page display logic
    if [[ ${#PAGES[@]} -gt 0 ]]; then
        text_lines+=("DOC PAGE $((CURRENT_DOC_PAGE+1))/${#PAGES[@]}")
        text_lines+=("----------------------------------------")
        local content_lines=()
        IFS=$'\n' read -d '' -ra content_lines <<< "${PAGES[$CURRENT_DOC_PAGE]}"
        for line in "${content_lines[@]}"; do
            # Truncate/Pad doc lines to fit panel width
            printf -v formatted_line "%-40.40s" "$line"
            text_lines+=("$formatted_line")
        done
        text_lines+=("----------------------------------------")
    else
        text_lines+=("NO DOC PAGES AVAILABLE")
        text_lines+=("") # Keep spacing consistent
        text_lines+=("----------------------------------------")
    fi

    # Collapsed count
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    text_lines+=("Collapsed: $collapsed_count / $((ROWS*COLS))")
    text_lines+=("----------------------------------------")
    text_lines+=("Controls (Small Mode):")
    text_lines+=("[Spc]Run/Pause [c]Step [f]Fullscreen")
    text_lines+=("[k/j]Algo Prv/Nxt [u/i]Fmt Prv/Nxt")
    text_lines+=("[p/n]Doc Prv/Nxt [e]Empty View")
    text_lines+=("[q]Quit [a/s/d/w/h/l/;]Algo Keys")
    text_lines+=("Controls (Large Mode):")
    text_lines+=("[Arrows] Algo (L/R) / Format (U/D)")

    # Return 0 for success (array is global)
    return 0
}


# --- Specific Rendering Modes ---

# Renders grid and text panel side-by-side (SMALL mode)
render_small() {
    # Build required data directly (uses ASCII 1x1 for grid)
    _build_ascii_1x1  # Populates global 'display_lines'
    _build_text_lines # Populates global 'text_lines'

    local grid_width=$COLS         # Use configured width
    local text_panel_width=40      # Fixed width for right-side panel
    local spacing="    "           # 4 spaces
    local spacing_width=${#spacing}

    # Use display_lines generated by _build_ascii_1x1 for the grid part
    local -n grid_source_lines="display_lines" # Use nameref for clarity

    # Determine max number of lines needed
    local max_lines=${#grid_source_lines[@]}
    if (( ${#text_lines[@]} > max_lines )); then
        max_lines=${#text_lines[@]}
    fi

    local output_buffer=""
    for ((i = 0; i < max_lines; i++)); do
        local grid_line="${grid_source_lines[i]:-}" # Get grid line or empty
        local text_line="${text_lines[i]:-}"       # Get text line or empty

        # Sanitize grid line (remove CR) - Important!
        grid_line=${grid_line//$'\r'/}

        # Ensure grid line is exactly COLS width (pad if needed, unlikely for ASCII)
        # Avoid printf formatting based on length here as it caused issues
        local current_grid_len=${#grid_line}
        if (( current_grid_len < grid_width )); then
             local pad_needed=$((grid_width - current_grid_len))
             local pad; printf -v pad "%${pad_needed}s"
             grid_line+="$pad"
        elif (( current_grid_len > grid_width )); then
             grid_line="${grid_line:0:$grid_width}" # Truncate if too long
        fi

        # Format the text panel line (pad/truncate)
        local formatted_text=""
        printf -v formatted_text "%-${text_panel_width}.${text_panel_width}s" "$text_line"

        # Append the combined line (using the potentially padded/truncated grid_line)
        output_buffer+="$grid_line$spacing$formatted_text"$'\n'
    done

    # Return the complete buffer for printing
    echo "$output_buffer"
}


# Renders the currently selected format centered (LARGE / Fullscreen mode)
render_large() {
    # Build the display lines based on CURRENT_RENDER_FORMAT
    if ! _build_display_lines; then
         # Handle error - build function should put error in display_lines
         log_event "Error building display lines for format $CURRENT_RENDER_FORMAT in render_large."
         # Allow rendering the error message stored in display_lines
    fi

    local grid_display_height=${#display_lines[@]}
    local grid_char_width=0 # Calculate actual width below

    if [[ $grid_display_height -eq 0 ]]; then
         display_lines+=("Error: No display lines generated for $CURRENT_RENDER_FORMAT.")
         grid_display_height=1
         grid_char_width=${#display_lines[0]}
    fi

    # Calculate max visual width from display lines (respecting potential ANSI codes)
    # Use 'wc -m' if available for better multi-byte/unicode width calculation
    local can_use_wc=0
    if command -v wc &>/dev/null && echo test | wc -m &>/dev/null; then
        can_use_wc=1
    fi

    for line in "${display_lines[@]}"; do
         local len=0
         # Strip ANSI codes before calculating width for accurate centering
         local clean_line; clean_line=$(echo -n "$line" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')

         if [[ $can_use_wc -eq 1 ]]; then
             len=$(echo -n "$clean_line" | wc -m)
         else
             len=${#clean_line} # Fallback to byte length
         fi
         (( len > grid_char_width )) && grid_char_width=$len
    done

    # Get terminal dimensions
    local term_rows=$(tput lines)
    local term_cols=$(tput cols)

    # Prevent grid_char_width from exceeding terminal width
    [[ $grid_char_width -gt $term_cols ]] && grid_char_width=$term_cols

    # Calculate centering offsets
    local row_offset=$(( (term_rows - grid_display_height) / 2 ))
    local col_offset=$(( (term_cols - grid_char_width) / 2 ))
    [[ $row_offset -lt 0 ]] && row_offset=0
    [[ $col_offset -lt 0 ]] && col_offset=0

    # Build the output buffer with positioning
    local output_buffer=""
    output_buffer+=$(printf "\033[%d;%dH" $((row_offset + 1)) 1) # Move to top-left of centered area (col 1)

    for ((i=0; i<${#display_lines[@]}; i++)); do
         # Pad line with spaces on the right to clear previous content and fill width
         local line_content="${display_lines[i]}"
         local clean_line; clean_line=$(echo -n "$line_content" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
         local current_visual_width=0
         if [[ $can_use_wc -eq 1 ]]; then current_visual_width=$(echo -n "$clean_line" | wc -m); else current_visual_width=${#clean_line}; fi

         local padding_needed=$((grid_char_width - current_visual_width))
         [[ $padding_needed -lt 0 ]] && padding_needed=0
         local padding_spaces; printf -v padding_spaces "%${padding_needed}s" ""

         # Construct final line: Move to correct column offset, print content, print padding
         local move_cmd; printf -v move_cmd "\033[%d;%dH" $((row_offset + i + 1)) $((col_offset + 1))
         output_buffer+="${move_cmd}${line_content}${padding_spaces}"
    done

    # Return the complete buffer for printing
    echo "$output_buffer"
}


# --- Main Render Dispatcher ---
# Calls the appropriate rendering function based on FULL_SCREEN mode
render() {
    local output_buffer=""

    if [[ $FULL_SCREEN -eq 1 ]]; then
        output_buffer=$(render_large) # Capture output
    else
        output_buffer=$(render_small) # Capture output
    fi

    # Clear screen THEN print the entire buffer at once
    # Use printf %s - safer than %b which interprets backslashes
    printf "\033[H\033[J%s" "$output_buffer"
}

