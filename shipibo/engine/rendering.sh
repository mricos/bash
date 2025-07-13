#!/usr/bin/env bash

# Engine Rendering Logic
# Uses engine/glyph.sh to map semantic states to renderable glyphs/styles.

source "./engine/glyph.sh" # Source the glyph engine

# --- Helper: Get Terminal Dimensions ---
# Tries to get terminal dimensions using stty size, falls back to tput.
# Outputs two lines: first is height, second is width.
# Falls back to defaults (e.g., 24x80) and logs a warning if both methods fail.
_get_terminal_dimensions() {
    log_event "_get_terminal_dimensions: Entering function" # DEBUG
    local height=24 width=80 # Defaults
    local got_dimensions=0
    local stty_out stty_h stty_w tput_h tput_w

    # Method 1: stty size (Often more reliable for current size)
    if command -v stty &>/dev/null; then
        stty_out=$(stty size 2>/dev/null)
        local stty_exit_code=$?
        log_event "_get_terminal_dimensions: stty exit=$stty_exit_code, output='$stty_out'" # DEBUG

        if [[ $stty_exit_code -eq 0 && "$stty_out" =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
            stty_h=${BASH_REMATCH[1]}
            stty_w=${BASH_REMATCH[2]}
            if [[ $stty_h -gt 0 && $stty_w -gt 0 ]]; then
                height=$stty_h
                width=$stty_w
                got_dimensions=1
                log_event "_get_terminal_dimensions: Got dimensions via stty: ${height}x${width}" # DEBUG
            else
                 # Log only if stty gave zero dimensions, not if it failed entirely
                 log_warn "RENDER: stty size returned zero dimensions ('$stty_out'). Trying tput."
            fi
        fi
    fi

    # Method 2: tput (Fallback if stty failed or didn't get valid dimensions)
    if [[ $got_dimensions -eq 0 ]] && command -v tput &>/dev/null; then
        tput_h=$(tput lines 2>/dev/null)
        tput_w=$(tput cols 2>/dev/null)

        log_event "_get_terminal_dimensions: tput h='$tput_h', w='$tput_w'" # DEBUG
        if [[ "$tput_h" =~ ^[0-9]+$ && $tput_h -gt 0 && "$tput_w" =~ ^[0-9]+$ && $tput_w -gt 0 ]]; then
            height=$tput_h
            width=$tput_w
            got_dimensions=1
            log_event "RENDER: Using dimensions from tput fallback: ${height}x${width}"
        fi
    fi

    # Final check if we are still using defaults (only log if both methods failed)
    if [[ $got_dimensions -eq 0 ]]; then
         log_warn "RENDER: FINAL: Failed to get dimensions via stty and tput. Using defaults ${height}x${width}."
    fi

    echo "$height"
    echo "$width"
    # Return status code: 0 if dimensions were found, 1 if defaults were used.
    [[ $got_dimensions -eq 1 ]] && return 0 || return 1
}

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

# Builds 1x1 view using get_state() and the glyph engine
_build_glyph_1x1() {
    display_lines=() # Clear/initialize output array

    # Check dependencies: get_state (algo), get_render_data (glyph engine)
    if ! declare -F get_state &>/dev/null; then
        display_lines+=("Error: Algo ${ALGO_FILE} missing get_state()")
        return 1
    fi
    if ! declare -F get_render_data &>/dev/null; then
         display_lines+=("Error: Glyph engine function get_render_data() not found")
         return 1
    fi

    # Pre-fetch render data for common semantic states
    local -A state_render_map # Map semantic state -> full styled string
    # Use ERROR_SYMBOL from config if available
    local error_sym="X"
    [[ -v ERROR_SYMBOL ]] && error_sym="$ERROR_SYMBOL"
    local common_states=("DEFAULT" " " "$error_sym") # Add more common states if known
    # TODO: Add algo-specific SYMBOLS if defined: common_states+=( "${SYMBOLS[@]}" )
    local state render_data glyph fg bg attr width styled_string
    for state in "${common_states[@]}"; do
        render_data=$(get_render_data "$state")
        IFS='|' read -r glyph fg bg attr width <<<"$render_data"
        # Handle potential empty parts gracefully
        styled_string="${attr}${bg}${fg}${glyph}"
        state_render_map["$state"]="$styled_string"
    done

    local reset_code=$(tput sgr0 2>/dev/null || echo "\033[0m")

    for ((row=0; row<ROWS; row++)); do
        local line=""
        for ((col=0; col<COLS; col++)); do
            local key="$row,$col"
            # 1. Get semantic state from algorithm
            local semantic_state=$(get_state $row $col)
            if [[ -z "$semantic_state" ]]; then
                semantic_state="DEFAULT"
            fi

            # 2. Look up pre-fetched styled string or fetch dynamically
            local render_string=""
            if [[ -v state_render_map["$semantic_state"] ]]; then
                render_string="${state_render_map[$semantic_state]}"
            else
                # Slow path for uncommon states
                # log_event "RENDER: Dynamic lookup for state '$semantic_state'"
                render_data=$(get_render_data "$semantic_state")
                IFS='|' read -r glyph fg bg attr width <<<"$render_data"
                render_string="${attr}${bg}${fg}${glyph}"
                # Cache it for this frame?
                state_render_map["$semantic_state"]="$render_string"
            fi

            # 3. Append the styled string
            line+="$render_string"
        done
        # Add reset at end of line
        display_lines+=("${line}${reset_code}") 
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
    # NOTE: We are replacing the simple version's CURRENT_RENDER_FORMAT with
    # the glyph engine's CURRENT_RENDER_MODE.
    case "$CURRENT_RENDER_MODE" in
        "ASCII")    _build_ascii_1x1 ;;
        # Use the new glyph builder for modes that require it
        "UTF8_BASIC"|"UTF8_COLOR"|"EMOJI") _build_glyph_1x1 ;; 
        # "TILED")    _build_tiled_nxn ;; # Disabled for now
        *)
            display_lines=() # Clear
            # Fallback to ASCII or glyph if mode is unknown but maybe defined in glyphs.conf
            log_warn "RENDER: Unknown render mode '$CURRENT_RENDER_MODE' in case statement. Trying glyph builder."
            _build_glyph_1x1 || _build_ascii_1x1 # Try glyph, then ASCII as last resort
            # display_lines+=("Error: Unknown render mode '$CURRENT_RENDER_MODE'")
            # return 1 
            ;;
    esac
    return $? # Return status of the build function
}

# --- Info Panel Builder ---
# Builds text lines for the info panel into global 'text_lines'
# Primarily used by render_small.
_build_text_lines() {
    text_lines=() # Clear/initialize global array

    # Add top padding
    text_lines+=("")
    text_lines+=("")

    # Doc page display logic
    if [[ ${#PAGES[@]} -gt 0 ]]; then
        local doc_text="${PAGES[$CURRENT_DOC_PAGE]}"
        # Use fixed width for now, matching render_small's text_panel_width
        local wrap_width=40
        # Wrap the text using fold, handle potential errors
        if command -v fold &> /dev/null; then
            # Use mapfile to read lines output by fold
            mapfile -t content_lines < <(echo -n "$doc_text" | fold -sw $wrap_width)
            log_event "RENDER DEBUG: Doc content lines after fold:" # DEBUG
            for line in "${content_lines[@]}"; do
                log_event "RENDER DEBUG:  -> [$line]" # DEBUG
                text_lines+=("$line")
            done
        else
            # Fallback if fold is not available: Manual split (less reliable wrapping)
            log_warn "RENDER: 'fold' command not found. Using basic line splitting for docs."
            IFS=$'\n' read -d '' -ra content_lines <<< "$doc_text"
            # Basic truncation as fallback
            local i
            for i in "${!content_lines[@]}"; do
                 [[ ${#content_lines[i]} -gt $wrap_width ]] && content_lines[i]=${content_lines[i]:0:$wrap_width}
            done
            # Add the processed lines to the text_lines array
            local line
            for line in "${content_lines[@]}"; do
                 text_lines+=("$line")
            done
        fi
    else
        text_lines+=("NO DOC PAGES AVAILABLE")
        text_lines+=("") # Keep spacing consistent
        text_lines+=("----------------------------------------")
    fi

    # Add Algorithm Status Message
    text_lines+=("----------------------------------------")
    text_lines+=("Status: ${STATUS_MESSAGE:-Idle}") # Show message or default

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
        grid_line=${grid_line//$'
'/}

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
        # DEBUG: Use raw text line without printf formatting
        formatted_text="$text_line" # Use raw line from fold
        # Original formatting (causes issues with some UTF chars?):
        # printf -v formatted_text "%-${text_panel_width}.${text_panel_width}s" "$text_line"
        # Add padding before reset if grid_line ends with one
        # This is complex. Simplification: Just append padding.
        output_buffer+="${grid_line}${grid_padding}${spacing}${formatted_text}"$'\n'
    done

    # Return the complete buffer for printing
    printf %s "$output_buffer"
}


# Renders the currently selected format centered (LARGE / Fullscreen mode)
render_large() {
    # Build the display lines based on CURRENT_RENDER_MODE
    if ! _build_display_lines; then
         # Handle error - build function should put error in display_lines
         log_event "Error building display lines for format $CURRENT_RENDER_MODE in render_large."
         # Allow rendering the error message stored in display_lines
    fi

    local grid_display_height=${#display_lines[@]}
    # The grid from _build_glyph_1x1 or _build_ascii_1x1 should be exactly COLS wide visually.
    local grid_char_width=${COLS:-40} # Use COLS global, default to 40

    if [[ $grid_display_height -eq 0 ]]; then
         display_lines+=("Error: No display lines generated for $CURRENT_RENDER_MODE.")
         grid_display_height=1
         grid_char_width=${#display_lines[0]}
    fi

    # Calculate max visual width from display lines (respecting potential ANSI codes)
    # Use 'wc -m' if available for better multi-byte/unicode width calculation
    local can_use_wc=0
    if command -v wc &>/dev/null && echo test | wc -m &>/dev/null; then
        can_use_wc=1
    fi

    # Get terminal dimensions
    local term_dims defaults_used=0
    term_dims=$(_get_terminal_dimensions) || defaults_used=1 # Capture return status
    local term_rows=$(echo "$term_dims" | sed -n 1p)
    local term_cols=$(echo "$term_dims" | sed -n 2p)

    # Prevent grid_char_width from exceeding terminal width
    [[ $grid_char_width -gt $term_cols ]] && grid_char_width=$term_cols

    # Calculate centering offsets
    local row_offset=$(( (term_rows - grid_display_height) / 2 ))
    local col_offset=$(( (term_cols - grid_char_width) / 2 ))
    [[ $row_offset -lt 0 ]] && row_offset=0
    [[ $col_offset -lt 0 ]] && col_offset=0

    # Build the output buffer with positioning using ANSI codes
    local render_large_buffer=""
    # Don't add the clear screen here, it's handled by the main render function
    # render_large_buffer+=$(printf "\\033[H\\033[J") # Clear screen

    for ((i=0; i<${#display_lines[@]}; i++)); do
         # Pad line with spaces on the right to clear previous content and fill width
         local line_content="${display_lines[i]}"
         local clean_line; clean_line=$(echo -n "$line_content" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
         local current_visual_width=0
         if [[ $can_use_wc -eq 1 ]]; then current_visual_width=$(echo -n "$clean_line" | wc -m); else current_visual_width=${#clean_line}; fi

         local padding_needed=$((grid_char_width - current_visual_width))
         [[ $padding_needed -lt 0 ]] && padding_needed=0
         local padding_spaces; printf -v padding_spaces "%${padding_needed}s" ""

         # Construct final line: Move to correct row/column offset, print content, print padding
         local move_cmd; printf -v move_cmd "\033[%d;%dH" $((row_offset + i + 1)) $((col_offset + 1))
         render_large_buffer+="${move_cmd}${line_content}${padding_spaces}"
    done

    # Return the complete buffer for printing by the main render function
    printf %s "$render_large_buffer"
}


# --- Main Render Dispatcher ---
# Calls the appropriate rendering function based on FULL_SCREEN mode
render() {
    # --- Consolidated Render --- #
    # Build a single command string for the entire screen update
    local output_commands=""
    output_commands+="$(tput clear 2>/dev/null || printf '\033[H\033[J')" # Clear screen
    output_commands+="$(tput civis 2>/dev/null)" # Hide cursor

    # --- Add Main Content Drawing Commands ---
    local defaults_used=0 # Need to track this for status bar
    if [[ $FULL_SCREEN -eq 1 ]]; then
        # render_large now returns the pre-formatted, centered content with ANSI positioning
        local centered_content=$(render_large)
        output_commands+="$centered_content" # Append it directly
    else # Small mode
        output_buffer=$(render_small) # render_small just returns the lines
        local -a lines_to_draw; mapfile -t lines_to_draw <<< "$output_buffer"
        local i
        for i in "${!lines_to_draw[@]}"; do
             output_commands+="$(tput cup $i 0 2>/dev/null)" # Position (top-left)
             output_commands+="$(tput el 2>/dev/null)" # Clear line
             output_commands+="${lines_to_draw[i]}" # Draw line
        done
    fi

    local term_dims defaults_used=0
    term_dims=$(_get_terminal_dimensions) || defaults_used=1 # Capture return status
    local term_rows=$(echo "$term_dims" | sed -n 1p)
    local term_cols=$(echo "$term_dims" | sed -n 2p)

    # --- Append Controls Overlay Commands (if enabled) ---
    if [[ ${SHOW_CONTROLS:-0} -eq 1 ]]; then
        local controls_lines_str=$(_draw_controls_overlay)
        if [[ -n "$controls_lines_str" ]]; then
             # Calculate position and dimensions (as before)
             local -a control_lines_array; mapfile -t control_lines_array <<< "$controls_lines_str"
             local controls_height=${#control_lines_array[@]}
             local controls_width=0; local line_width=0; local clean_line=""
             for line_content in "${control_lines_array[@]}"; do
                  clean_line=$(echo -n "$line_content" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
                  if command -v wc &> /dev/null; then line_width=$(echo -n "$clean_line" | wc -m); else line_width=${#clean_line}; fi
                  (( line_width > controls_width )) && controls_width=$line_width
             done

             local target_controls_row_0_based=$(( term_rows - 2 - controls_height ))
             local target_controls_col_0_based=$(( (term_cols - controls_width) / 2 ))
             [[ $target_controls_row_0_based -lt 0 ]] && target_controls_row_0_based=0
             [[ $target_controls_col_0_based -lt 0 ]] && target_controls_col_0_based=0

             # Append drawing commands
             log_event "RENDER DEBUG: Controls Overlay. TargetRow0=${target_controls_row_0_based}, TargetCol0=${target_controls_col_0_based}, Width=${controls_width}, Height=${controls_height}"
             local i line_content move_cmd
             for i in "${!control_lines_array[@]}"; do
                 line_content="${control_lines_array[i]}"
                 move_cmd=$(tput cup $(( target_controls_row_0_based + i )) $target_controls_col_0_based 2>/dev/null)
                 output_commands+="${move_cmd}${line_content}" # Append move and line content
             done
        fi
    # Note: No explicit clearing needed when hidden; main redraw overwrites.
    fi

    # --- Append Status Bar Commands ---
    local status_row=$((term_rows - 1))
    [[ $status_row -lt 0 ]] && status_row=0
    local status_row2=$((term_rows - 2))
    [[ $status_row2 -lt 0 ]] && status_row2=0

    # Ensure defaults are used if extraction failed
    [[ -z "$term_rows" || -z "$term_cols" ]] && term_rows=24 && term_cols=80 && defaults_used=1

    # Construct status string (as before)
    # --- Line 1 (Bottom) --- 
    local run_status="Paused"
    [[ $RUNNING -eq 1 ]] && run_status="Running"
    local default_indicator=""
    [[ $defaults_used -eq 1 ]] && default_indicator="(Def) "
    local algo_mode_indicator=""
    if [[ "$ALGO_FILE" == "blocky.sh" && -v BLOCKY_RULE_MODE ]]; then
        # Try calling the algo-specific function for the name
        if declare -F get_current_mode_name &>/dev/null; then
            local friendly_name
            friendly_name=$(get_current_mode_name) # Call the function
            algo_mode_indicator=" (${friendly_name:-$BLOCKY_RULE_MODE})" # Fallback to number
        else
            algo_mode_indicator=" (${BLOCKY_RULE_MODE})"
        fi
    fi

    local status_string1="Term:${default_indicator}${term_rows}x${term_cols} | Algo: ${ALGO_FILE}${algo_mode_indicator} | ${run_status}"

    # Add collapsed count if applicable
    if declare -p collapsed &>/dev/null && [[ ${#collapsed[@]} -gt 0 ]]; then
        local collapsed_count=0
        local total_cells=$((ROWS*COLS)) # Assuming ROWS/COLS are correct
        # Efficiently count set values (Bash 4+)
        local count_str; count_str=$(printf "%s\\n" "${collapsed[@]}" | grep -c '1')
        [[ "$count_str" =~ ^[0-9]+$ ]] && collapsed_count=$count_str
        status_string1+=" | Collapsed: ${collapsed_count}/${total_cells}"
    fi

    # --- Line 2 (Second to Bottom) ---
    local status_string2="Display: ${CURRENT_RENDER_MODE}"
    # Append custom STATUS_MESSAGE if set and non-empty
    [[ -n "${STATUS_MESSAGE}" ]] && status_string2+=" | ${STATUS_MESSAGE}"

    # Calculate length *without* potential ANSI codes for accurate padding
    local clean_status_string1=$(echo -n "$status_string1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
    local status_len1=${#clean_status_string1}
    local clean_status_string2=$(echo -n "$status_string2" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
    local status_len2=${#clean_status_string2}

    local padding_needed1=$((term_cols - status_len1))
    [[ $padding_needed1 -lt 0 ]] && padding_needed1=0
    local padding_spaces1; printf -v padding_spaces1 "%${padding_needed1}s" ""

    local padding_needed2=$((term_cols - status_len2))
    [[ $padding_needed2 -lt 0 ]] && padding_needed2=0
    local padding_spaces2; printf -v padding_spaces2 "%${padding_needed2}s" ""

    # Get tput codes (dim might fail gracefully)
    local move_to_status_line1=$(tput cup ${status_row} 0 2>/dev/null)
    local move_to_status_line2=$(tput cup ${status_row2} 0 2>/dev/null)
    local clear_line=$(tput el 2>/dev/null)
    local set_dim=$(tput dim 2>/dev/null || echo "")
    local reset_attrs=$(tput sgr0 2>/dev/null || echo "\033[0m")

    log_event "RENDER DEBUG: Drawing status bar. term_rows=${term_rows}, status_row=${status_row}."
    # Add commands for BOTH status lines
    output_commands+="${move_to_status_line2}${clear_line}${set_dim}${status_string2}${padding_spaces2}${reset_attrs}" # Line 2 (Draw first to avoid flicker?)
    output_commands+="${move_to_status_line1}${clear_line}${set_dim}${status_string1}${padding_spaces1}${reset_attrs}" # Line 1 (Bottom)
    # --- End Status Bar Commands ---

    # Append final cursor positioning and visibility commands
    output_commands+="$(tput cup ${status_row} 0 2>/dev/null)" # Position cursor at start of status line
    output_commands+="$(tput cnorm 2>/dev/null)" # Make cursor visible

    # Execute all commands at once
    printf %s "$output_commands"
}

# --- Draw Controls Overlay ---
# Generates the text lines for the controls overlay based on global arrays.
# Formats controls into columns.
# Returns a string containing formatted lines with newline separators.
# (Adapted from previous version)
_draw_controls_overlay() {
    if [[ ! -v CONTROL_KEYS || ${#CONTROL_KEYS[@]} -eq 0 ]]; then
        echo " [ Controls data not loaded ] " # Return a single line message
        return
    fi

    local -a overlay_lines # Array to hold the final output lines
    local total_items=${#CONTROL_KEYS[@]}

    # --- Layout Configuration ---
    local num_cols=4
    local target_col_width=24 # Increased width for alignment
    local col_spacing_width=2 # Spaces between columns
    local col_spacing_str; printf -v col_spacing_str "%${col_spacing_width}s" ""

    # --- Calculate Rows Needed ---
    local num_rows=$(( (total_items + num_cols - 1) / num_cols ))
    [[ $num_rows -eq 0 ]] && return # No items, nothing to draw

    # --- Build Lines --- 
    for (( row=0; row < num_rows; row++ )); do
        local current_line=""
        for (( col=0; col < num_cols; col++ )); do
            local item_index=$(( row + col * num_rows )) # Fill columns first

            if (( item_index < total_items )); then
                local key="${CONTROL_KEYS[item_index]}"
                local label="${CONTROL_LABELS[item_index]}"
                local display_key="$key"
                # Handle special key names for display
                case "$key" in
                    SPACE) display_key="Spc" ;;
                    LEFT) display_key="←" ;;
                    RIGHT) display_key="→" ;;
                    UP) display_key="↑" ;;
                    DOWN) display_key="↓" ;;
                    # Add more if needed (e.g., ESC, ENTER)
                esac
                # Format: [Key] Label
                local item_text="[${display_key}] ${label}"
                local padded_item=""
                printf -v padded_item "%-${target_col_width}.${target_col_width}s" "$item_text"
                current_line+="$padded_item"
            else
                # Pad empty slots in the column
                local empty_col_padding; printf -v empty_col_padding "%${target_col_width}s" ""
                current_line+="$empty_col_padding"
            fi

            if (( col < num_cols - 1 )); then
                current_line+="$col_spacing_str"
            fi
        done # End column loop

        overlay_lines+=("$current_line") # Add completed line to array
    done # End row loop

    # Join lines with newline and return
    local IFS=$'\n'
    echo "${overlay_lines[*]}"
}

