#!/bin/bash
# grid2.sh - WFC with 2x2 Tile logic, using NAMES internally,
#            outputs single chars to 'possibilities' array for engine 1x1 view.

# --- Algorithm Metadata ---
export ALGO_TILE_WIDTH=2
export ALGO_TILE_HEIGHT=2

# --- Rendering Glyphs (used by simple_engine.sh NxN render mode) ---
declare -gA TILE_TOPS
declare -gA TILE_BOTS
export TILE_TOPS
export TILE_BOTS

TILE_TOPS["STRAIGHT_H"]="═══ ═══"; TILE_BOTS["STRAIGHT_H"]="═══ ═══"
TILE_TOPS["STRAIGHT_V"]=" ║   ║ "; TILE_BOTS["STRAIGHT_V"]=" ║   ║ "
TILE_TOPS["BEND_NE"]="    ║ "; TILE_BOTS["BEND_NE"]="═══ ═╝ "
TILE_TOPS["BEND_NW"]=" ║     "; TILE_BOTS["BEND_NW"]=" ╚═ ═══"
TILE_TOPS["BEND_SE"]="═══ ═╗ "; TILE_BOTS["BEND_SE"]="    ║ "
TILE_TOPS["BEND_SW"]=" ╔═ ═══"; TILE_BOTS["BEND_SW"]=" ║     "
TILE_TOPS["CROSS"]=" ║   ║ "; TILE_BOTS["CROSS"]="═╬═ ═╬═"
TILE_TOPS["T_NORTH"]=" ║   ║ "; TILE_TOPS["T_NORTH"]="═╩═ ═══"
TILE_TOPS["T_EAST"]=" ║     "; TILE_TOPS["T_EAST"]=" ╠═ ═══"
TILE_TOPS["T_SOUTH"]="═╦═ ═══"; TILE_TOPS["T_SOUTH"]=" ║   ║ "
TILE_TOPS["T_WEST"]="    ║ "; TILE_TOPS["T_WEST"]="═══ ═╣ "

# --- Character Mapping (used for 1x1 display / possibilities array) ---
declare -gA TILE_NAME_TO_CHAR
TILE_NAME_TO_CHAR["STRAIGHT_H"]="H"; TILE_NAME_TO_CHAR["STRAIGHT_V"]="V"
TILE_NAME_TO_CHAR["BEND_NE"]="N"; TILE_NAME_TO_CHAR["BEND_NW"]="W"
TILE_NAME_TO_CHAR["BEND_SE"]="S"; TILE_NAME_TO_CHAR["BEND_SW"]="T"
TILE_NAME_TO_CHAR["CROSS"]="C"
TILE_NAME_TO_CHAR["T_NORTH"]="U"; TILE_NAME_TO_CHAR["T_EAST"]="R"
TILE_NAME_TO_CHAR["T_SOUTH"]="D"; TILE_NAME_TO_CHAR["T_WEST"]="L"
TILE_NAME_TO_CHAR["ERROR"]="×" # Map internal error name to char
export TILE_NAME_TO_CHAR # Export for engine's 1x1 renderer

# Reverse mapping (optional internal use)
declare -gA CHAR_TO_TILE_NAME
for name in "${!TILE_NAME_TO_CHAR[@]}"; do CHAR_TO_TILE_NAME[${TILE_NAME_TO_CHAR[$name]}]="$name"; done

# --- Core WFC Setup ---
# Use TILE NAMES for internal SYMBOLS array
export SYMBOLS=("STRAIGHT_H" "STRAIGHT_V" "BEND_NE" "BEND_NW" "BEND_SE" "BEND_SW" "CROSS" "T_NORTH" "T_EAST" "T_SOUTH" "T_WEST")
# ERROR_SYMBOL is the internal NAME representation
export ERROR_SYMBOL="ERROR"

# Updated PAGES array
PAGES=(
"WFC: 2x2 Logic / Dual Render
-----------------------------
Internal: Uses tile NAMES.
Grid: Stores final NAMES.
Possibilities: Stores CHARS.
Render: 1x1 (chars) / NxN (glyphs)."

"WFC Rules: 2x2 Tile Logic
---------------------------
Internal rules define which 2x2
tile NAMES can connect based on
matching openings on adjacent edges."

"WFC Implementation Notes
---------------------------
- Grid array: tile names.
- Possibilities array: single chars.
- Engine render uses appropriate array."
)
export PAGES

# ───── Helper Functions ─────

# Function to convert space-separated tile names to a string of single chars
convert_names_to_chars() {
    local names_str="$1"
    local chars_str=""
    local -a names_arr=($names_str)
    for name in "${names_arr[@]}"; do
         if [[ "$name" == "$ERROR_SYMBOL" ]]; then
             chars_str+="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"
         elif [[ -v TILE_NAME_TO_CHAR[$name] ]]; then
             chars_str+="${TILE_NAME_TO_CHAR[$name]}"
         fi
    done
    echo "$chars_str"
}

# Propagate function - Using constraints from collapsed neighbors only
# Modifies 'grid' (names) and 'possibilities' (chars)
propagate() {
    local start_y="$1"; local start_x="$2"; local -a queue=(); local -A processed_in_wave # Use ; for brevity
    local -a directions=("left" "right" "up" "down"); local processed_count=0; local max_processed=10000

    for dir in "${directions[@]}"; do
         local ny; local nx; case "$dir" in left) ny="$start_y";nx=$((start_x-1));; right) ny="$start_y";nx=$((start_x+1));; up) ny=$((start_y-1));nx="$start_x";; down) ny=$((start_y+1));nx="$start_x";; esac; local nkey="$ny,$nx"
         if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && [[ "${collapsed[$nkey]:-0}" == "0" ]]; then local in_queue=0; for item in "${queue[@]}"; do [[ "$item" == "$nkey" ]] && { in_queue=1; break; }; done; [[ $in_queue -eq 0 ]] && queue+=("$nkey"); fi
    done

    while (( ${#queue[@]} > 0 && processed_count < max_processed )); do
        ((processed_count++)); local current_key="${queue[0]}"; queue=("${queue[@]:1}")
        if [[ -v processed_in_wave["$current_key"] ]]; then continue; fi; processed_in_wave["$current_key"]=1

        local cy="${current_key%,*}"; local cx="${current_key#*,}"
        local original_options_names="${grid[$current_key]-}"
        local original_options_chars="${possibilities[$current_key]-}"
        if [[ "$original_options_names" == "$ERROR_SYMBOL" ]]; then continue; fi

        if [[ "${collapsed[$current_key]:-0}" == "0" ]]; then
            local -a surviving_names_arr=($original_options_names)
        else
            local -a surviving_names_arr=("$original_options_names")
        fi

        local possibilities_reduced=0

        for dir in "${directions[@]}"; do
            local ny; local nx; local opposite_dir; case "$dir" in left) ny="$cy";nx=$((cx-1));opposite_dir="right";; right) ny="$cy";nx=$((cx+1));opposite_dir="left";; up) ny=$((cy-1));nx="$cx";opposite_dir="down";; down) ny=$((cy+1));nx="$cx";opposite_dir="up";; esac; local nkey="$ny,$nx"
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )) || [[ "${collapsed[$nkey]:-0}" == "0" ]]; then continue; fi

            local neighbor_name="${grid[$nkey]-}"
            if [[ "$neighbor_name" == "$ERROR_SYMBOL" ]] || [[ -z "$neighbor_name" ]]; then continue; fi

            local rule_key="${neighbor_name}_${opposite_dir}"
            local allowed_names_by_neighbor=" ${rules[$rule_key]-} "

            local -a next_surviving_names_arr=()
            for potential_name in "${surviving_names_arr[@]}"; do
                if [[ -n "$potential_name" && "$allowed_names_by_neighbor" == *" $potential_name "* ]]; then
                     next_surviving_names_arr+=("$potential_name")
                fi
            done
            
            if (( ${#surviving_names_arr[@]} != ${#next_surviving_names_arr[@]} )); then
                possibilities_reduced=1
                surviving_names_arr=("${next_surviving_names_arr[@]}")
                if (( ${#surviving_names_arr[@]} == 0 )); then break; fi
            fi
        done

        if (( ${#surviving_names_arr[@]} == 0 )); then
            if [[ "$original_options_names" != "$ERROR_SYMBOL" ]]; then
                 echo "!!!!!! CONTRADICTION in propagate at $current_key. Original names: [$original_options_names]." >> "$LOG_FILE"
                 grid[$current_key]="$ERROR_SYMBOL"
                 possibilities[$current_key]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"
                 collapsed[$current_key]=1
             fi; continue
        fi

        if [[ $possibilities_reduced -eq 1 ]]; then
             local new_options_names=$(IFS=' '; echo "${surviving_names_arr[*]}")
             local new_options_chars=$(convert_names_to_chars "$new_options_names")

             if [[ "$original_options_names" != "$new_options_names" ]]; then
                 echo "Propagate $current_key: Names reduced from [$original_options_names] to [$new_options_names], Chars: [$new_options_chars]" >> "$LOG_FILE"
                 grid[$current_key]="$new_options_names"
                 possibilities[$current_key]="$new_options_chars"

                 for dir2 in "${directions[@]}"; do
                     local nny; local nnx; case "$dir2" in left) nny="$cy";nnx=$((cx-1));; right) nny="$cy";nnx=$((cx+1));; up) nny=$((cy-1));nx="$cx";; down) nny=$((cy+1));nx="$cx";; esac; local nnkey="$nny,$nnx"
                     if (( nny >= 0 && nny < ROWS && nnx >= 0 && nnx < COLS )) && [[ "${collapsed[$nnkey]:-0}" == "0" ]]; then local nn_in_queue=0; for item in "${queue[@]}"; do [[ "$item" == "$nnkey" ]] && { nn_in_queue=1; break; }; done; [[ $nn_in_queue -eq 0 ]] && queue+=("$nnkey"); fi
                 done
             fi
        fi

        if (( ${#surviving_names_arr[@]} == 1 )); then
             if [[ "${collapsed[$current_key]:-0}" == "0" ]]; then
                  collapsed[$current_key]=1
                  possibilities[$current_key]="${TILE_NAME_TO_CHAR[${surviving_names_arr[0]}]}"
                  echo "Auto-collapsed $current_key to '${surviving_names_arr[0]}'" >> "$LOG_FILE"
             fi
        fi
    done
    if (( processed_count >= max_processed )); then echo "ERROR (propagate): Exceeded max steps." >> "$LOG_FILE"; STATUS_MESSAGE="Error: Propagation loop."; fi
}

# ───── Engine-Called Functions ─────

# Initialize connection rules (Using TILE NAMES)
init_rules() {
    rules=() # Clear global rules
    echo "INFO (grid2.sh): Initializing 2x2 Tube Network rules (using tile names)..." >> "$LOG_FILE"
    local opens_right="STRAIGHT_H BEND_NE BEND_SE CROSS T_NORTH T_SOUTH T_WEST"
    local opens_left="STRAIGHT_H BEND_NW BEND_SW CROSS T_NORTH T_SOUTH T_EAST"
    local opens_top="STRAIGHT_V BEND_NW BEND_NE CROSS T_EAST T_WEST T_SOUTH"
    local opens_bottom="STRAIGHT_V BEND_SW BEND_SE CROSS T_EAST T_WEST T_NORTH"
    rules["STRAIGHT_H_left"]="$opens_right"; rules["STRAIGHT_H_right"]="$opens_left"; rules["STRAIGHT_H_up"]=""; rules["STRAIGHT_H_down"]=""
    rules["STRAIGHT_V_left"]=""; rules["STRAIGHT_V_right"]=""; rules["STRAIGHT_V_up"]="$opens_bottom"; rules["STRAIGHT_V_down"]="$opens_top"
    rules["BEND_NE_left"]=""; rules["BEND_NE_right"]="$opens_left"; rules["BEND_NE_up"]="$opens_bottom"; rules["BEND_NE_down"]=""
    rules["BEND_NW_left"]="$opens_right"; rules["BEND_NW_right"]=""; rules["BEND_NW_up"]="$opens_bottom"; rules["BEND_NW_down"]=""
    rules["BEND_SE_left"]=""; rules["BEND_SE_right"]="$opens_left"; rules["BEND_SE_up"]=""; rules["BEND_SE_down"]="$opens_top"
    rules["BEND_SW_left"]="$opens_right"; rules["BEND_SW_right"]=""; rules["BEND_SW_up"]=""; rules["BEND_SW_down"]="$opens_top"
    rules["T_NORTH_left"]="$opens_right"; rules["T_NORTH_right"]="$opens_left"; rules["T_NORTH_up"]="$opens_bottom"; rules["T_NORTH_down"]=""
    rules["T_EAST_left"]=""; rules["T_EAST_right"]="$opens_left"; rules["T_EAST_up"]="$opens_bottom"; rules["T_EAST_down"]="$opens_top"
    rules["T_SOUTH_left"]="$opens_right"; rules["T_SOUTH_right"]="$opens_left"; rules["T_SOUTH_up"]=""; rules["T_SOUTH_down"]="$opens_top"
    rules["T_WEST_left"]="$opens_right"; rules["T_WEST_right"]=""; rules["T_WEST_up"]="$opens_bottom"; rules["T_WEST_down"]="$opens_top"
    rules["CROSS_left"]="$opens_right"; rules["CROSS_right"]="$opens_left"; rules["CROSS_up"]="$opens_bottom"; rules["CROSS_down"]="$opens_top"
    local -a all_tile_names=("${SYMBOLS[@]}"); local -a all_dirs=("left" "right" "up" "down")
    for name in "${all_tile_names[@]}"; do for dir in "${all_dirs[@]}"; do local rule_key="${name}_${dir}"; printf -v rules["$rule_key"] '%s' "${rules[$rule_key]:-}"; done; done
    echo "INFO (grid2.sh): 2x2 Tube Network rules initialized." >> "$LOG_FILE"
}

# Initialize grid: 'grid' has names, 'possibilities' has chars. Seed 'CROSS'/'C'.
init_grid() {
    grid=(); possibilities=(); collapsed=()
    local all_symbols_names="${SYMBOLS[*]}" # String of names
    local all_symbols_chars=$(convert_names_to_chars "$all_symbols_names") # String of chars

    echo "INFO (grid2.sh): Initializing grid (${ROWS}x${COLS}). Grid=Names, Possibilities=Chars." >> "$LOG_FILE"
    echo "INFO (grid2.sh): Initial possibilities string: '$all_symbols_chars'" >> "$LOG_FILE"

    for ((y=0; y<ROWS; y++)); do for ((x=0; x<COLS; x++)); do local key="$y,$x"
        grid[$key]="$all_symbols_names"; possibilities[$key]="$all_symbols_chars"; collapsed[$key]=0
    done; done

    local seed_y=$((ROWS/2)); local seed_x=$((COLS/2)); local seed_key="$seed_y,$seed_x"
    local seed_name="CROSS"; local seed_char="${TILE_NAME_TO_CHAR[$seed_name]}"

    if [[ -v grid["$seed_key"] ]]; then
        grid[$seed_key]="$seed_name"; possibilities[$seed_key]="$seed_char"; collapsed[$seed_key]=1
        echo "INFO (grid2.sh): Seeded $seed_key. Grid='$seed_name', Poss='$seed_char'." >> "$LOG_FILE"
        propagate "$seed_y" "$seed_x"
    else echo "WARN (grid2.sh): Seed key $seed_key invalid." >> "$LOG_FILE"; fi

    local contradictions=0; for key in "${!grid[@]}"; do [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]] && contradictions=1 && break; done
    if [[ $contradictions -eq 1 ]]; then echo "ERROR (grid2.sh): Contradiction after init!" >> "$LOG_FILE"; STATUS_MESSAGE="Error: Initial contradiction."; else echo "INFO (grid2.sh): Grid init OK." >> "$LOG_FILE"; fi
}

# Find cell with minimum entropy (fewest names in grid array) and collapse it
update_algorithm() {
    local min_entropy=99999; local -a candidates=(); local potential_contradiction=0; local all_cells_collapsed_check=1

    for key in "${!collapsed[@]}"; do
        if [[ "${collapsed[$key]:-0}" == "0" ]]; then all_cells_collapsed_check=0
            local current_options_names="${grid[$key]-}"
            if [[ "$current_options_names" == "$ERROR_SYMBOL" ]]; then potential_contradiction=1; [[ "${collapsed[$key]}" == "0" ]] && collapsed[$key]=1; continue; fi
            local -a opts_arr=($current_options_names); local entropy=${#opts_arr[@]}
            if (( entropy == 0 )); then echo "!!!!!! CONTRADICTION in update for $key. Names empty." >> "$LOG_FILE"; potential_contradiction=1; grid[$key]="$ERROR_SYMBOL"; possibilities[$key]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"; collapsed[$key]=1; continue; fi
            if (( entropy < min_entropy )); then min_entropy=$entropy; candidates=("$key"); elif (( entropy == min_entropy )); then local exists=0; for cand in "${candidates[@]}"; do [[ "$cand" == "$key" ]] && { exists=1; break; }; done; [[ $exists -eq 0 ]] && candidates+=("$key"); fi
        fi
    done

    if [[ $all_cells_collapsed_check -eq 1 ]]; then local final_contradiction=0; for key in "${!grid[@]}"; do [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]] && final_contradiction=1 && break; done; if [[ $final_contradiction -eq 1 ]]; then STATUS_MESSAGE="WFC Error: Contradictions remain."; else STATUS_MESSAGE="WFC Complete!"; fi; return 1; fi
    if (( ${#candidates[@]} == 0 )); then if [[ $potential_contradiction -eq 1 ]]; then STATUS_MESSAGE="WFC Error: Contradiction."; else STATUS_MESSAGE="WFC Error: No candidates."; fi; return 1; fi

    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"; local y="${pick%,*}"; local x="${pick#*,}"
    local options_names="${grid[$pick]}"; local -a options_arr=($options_names)
    if (( ${#options_arr[@]} == 0 )); then STATUS_MESSAGE="WFC Error: Picked has 0 options!"; grid[$pick]="$ERROR_SYMBOL"; possibilities[$pick]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"; collapsed[$pick]=1; return 1; fi

    local chosen_name="${options_arr[$((RANDOM % ${#options_arr[@]}))]}"; local chosen_char="${TILE_NAME_TO_CHAR[$chosen_name]}"
    grid[$pick]="$chosen_name"; possibilities[$pick]="$chosen_char"; collapsed[$pick]=1
    echo "DEBUG (grid2.sh Update): Collapsed $pick to name '$chosen_name' (char '$chosen_char', Entropy $min_entropy)." >> "$LOG_FILE"

    propagate "$y" "$x"
    local collapsed_count=0; for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]:-0}" == "1" ]] && ((collapsed_count++)); done; local total_cells=$((ROWS * COLS))
    STATUS_MESSAGE="Collapsed $pick ('$chosen_name') | $collapsed_count/$total_cells"
    return 0
}

# End of grid2.sh