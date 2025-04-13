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
# Fix: Corrected T-junction tile definitions to prevent overwriting themselves
TILE_TOPS["T_NORTH"]=" ║   ║ "; TILE_BOTS["T_NORTH"]="═╩═ ═══"
TILE_TOPS["T_EAST"]=" ║     "; TILE_BOTS["T_EAST"]=" ╠═ ═══"
TILE_TOPS["T_SOUTH"]="═╦═ ═══"; TILE_BOTS["T_SOUTH"]=" ║   ║ "
TILE_TOPS["T_WEST"]="    ║ "; TILE_BOTS["T_WEST"]="═══ ═╣ "

# --- Character Mapping (updated error symbol) ---
declare -gA TILE_NAME_TO_CHAR
TILE_NAME_TO_CHAR["STRAIGHT_H"]="H"; TILE_NAME_TO_CHAR["STRAIGHT_V"]="V"
TILE_NAME_TO_CHAR["BEND_NE"]="N"; TILE_NAME_TO_CHAR["BEND_NW"]="W"
TILE_NAME_TO_CHAR["BEND_SE"]="S"; TILE_NAME_TO_CHAR["BEND_SW"]="T"
TILE_NAME_TO_CHAR["CROSS"]="C"
TILE_NAME_TO_CHAR["T_NORTH"]="U"; TILE_NAME_TO_CHAR["T_EAST"]="R"
TILE_NAME_TO_CHAR["T_SOUTH"]="D"; TILE_NAME_TO_CHAR["T_WEST"]="L"
TILE_NAME_TO_CHAR["ERROR"]="×" # Change from "X" to "×" for visual clarity
export TILE_NAME_TO_CHAR # Export for engine's 1x1 renderer

# Reverse mapping (optional internal use)
declare -gA CHAR_TO_TILE_NAME
for name in "${!TILE_NAME_TO_CHAR[@]}"; do CHAR_TO_TILE_NAME[${TILE_NAME_TO_CHAR[$name]}]="$name"; done

# --- Core WFC Setup (update error symbol name) ---
export SYMBOLS=("STRAIGHT_H" "STRAIGHT_V" "BEND_NE" "BEND_NW" "BEND_SE" "BEND_SW" "CROSS" "T_NORTH" "T_EAST" "T_SOUTH" "T_WEST")
export ERROR_SYMBOL="ERROR" # Explicitly define and export

# Add Tile Weights for selection bias
declare -gA TILE_WEIGHTS
TILE_WEIGHTS["STRAIGHT_H"]=10  # INCREASED: Strongly prefer straight pieces
TILE_WEIGHTS["STRAIGHT_V"]=10  # INCREASED
TILE_WEIGHTS["BEND_NE"]=1     # DECREASED: Lower preference for corners
TILE_WEIGHTS["BEND_NW"]=1     # DECREASED
TILE_WEIGHTS["BEND_SE"]=1     # DECREASED
TILE_WEIGHTS["BEND_SW"]=1     # DECREASED
TILE_WEIGHTS["T_NORTH"]=0.5     # DECREASED: Very low preference for T-junctions
TILE_WEIGHTS["T_EAST"]=0.5      # DECREASED
TILE_WEIGHTS["T_SOUTH"]=0.5     # DECREASED
TILE_WEIGHTS["T_WEST"]=0.5      # DECREASED
TILE_WEIGHTS["CROSS"]=0.1     # DECREASED: Lowest preference for crosses

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
         [[ -v TILE_NAME_TO_CHAR[$name] ]] && chars_str+="${TILE_NAME_TO_CHAR[$name]}"
    done
    echo "$chars_str"
}

# Propagate function - revert contradiction handling
propagate() {
    local start_y="$1"; local start_x="$2"; local -a queue=(); local -A processed_in_wave # Use ; for brevity
    local -a directions=("left" "right" "up" "down"); local processed_count=0; local max_processed=10000

    # Fix: Add the starting cell's neighbors to the queue
    for dir in "${directions[@]}"; do
         local ny; local nx
         case "$dir" in 
             left) ny="$start_y"; nx=$((start_x-1)) ;;
             right) ny="$start_y"; nx=$((start_x+1)) ;;
             up) ny=$((start_y-1)); nx="$start_x" ;;
             down) ny=$((start_y+1)); nx="$start_x" ;;
         esac
         local nkey="$ny,$nx"
         if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && [[ "${collapsed[$nkey]:-0}" == "0" ]]; then
             # Fix: Better check if already in queue
             local in_queue=0
             for item in "${queue[@]}"; do 
                 [[ "$item" == "$nkey" ]] && { in_queue=1; break; }
             done
             [[ $in_queue -eq 0 ]] && queue+=("$nkey")
         fi
    done

    while (( ${#queue[@]} > 0 && processed_count < max_processed )); do
        ((processed_count++))
        local current_key="${queue[0]}"
        queue=("${queue[@]:1}") # Remove first element
        
        # Skip if already processed in this wave
        if [[ -v processed_in_wave["$current_key"] ]]; then continue; fi
        processed_in_wave["$current_key"]=1

        local cy="${current_key%,*}"
        local cx="${current_key#*,}"
        local original_options_names="${grid[$current_key]-}"
        local original_options_chars="${possibilities[$current_key]-}"
        
        # Skip error cells
        if [[ "$original_options_names" == "$ERROR_SYMBOL" ]]; then continue; fi

        local -a surviving_names_arr=($original_options_names)
        local possibilities_reduced=0

        # For each direction, check collapsed neighbors and apply constraints
        for dir in "${directions[@]}"; do
            local ny; local nx; local opposite_dir
            case "$dir" in 
                left) ny="$cy"; nx=$((cx-1)); opposite_dir="right" ;;
                right) ny="$cy"; nx=$((cx+1)); opposite_dir="left" ;;
                up) ny=$((cy-1)); nx="$cx"; opposite_dir="down" ;;
                down) ny=$((cy+1)); nx="$cx"; opposite_dir="up" ;;
            esac
            local nkey="$ny,$nx"
            
            # Skip if out of bounds or not collapsed
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )) || [[ "${collapsed[$nkey]:-0}" == "0" ]]; then
                continue
            fi

            local neighbor_name="${grid[$nkey]-}"
            if [[ "$neighbor_name" == "$ERROR_SYMBOL" ]] || [[ -z "$neighbor_name" ]]; then
                continue
            fi

            # Get the allowed tile names in this position based on neighbor constraints
            local rule_key="${neighbor_name}_${opposite_dir}"
            local allowed_names_by_neighbor=" ${rules[$rule_key]-} "
            
            # Filter surviving tiles
            local -a next_surviving_names_arr=()
            for potential_name in "${surviving_names_arr[@]}"; do
                [[ "$allowed_names_by_neighbor" == *" $potential_name "* ]] && next_surviving_names_arr+=("$potential_name")
            done

            # If options were reduced, update the surviving names
            if (( ${#surviving_names_arr[@]} != ${#next_surviving_names_arr[@]} )); then
                possibilities_reduced=1
                surviving_names_arr=("${next_surviving_names_arr[@]}")
                if (( ${#surviving_names_arr[@]} == 0 )); then
                    break
                fi
            fi
        done

        # Handle contradiction (no surviving options) - Reverted to simple error marking
        if (( ${#surviving_names_arr[@]} == 0 )); then
            if [[ "$original_options_names" != "$ERROR_SYMBOL" ]]; then
                echo "!!!!!! CONTRADICTION in propagate at $current_key. Original names: [$original_options_names]." >> "$DEBUG_LOG_FILE"
                grid[$current_key]="$ERROR_SYMBOL"
                possibilities[$current_key]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}" # Store error char
                collapsed[$current_key]=1
            fi
            continue # Skip further processing for this cell
        fi

        # If possibilities were reduced, update grid and queue neighbors
        if [[ $possibilities_reduced -eq 1 ]]; then
             local new_options_names=$(IFS=' '; echo "${surviving_names_arr[*]}")
             local new_options_chars=$(convert_names_to_chars "$new_options_names")

             # Check if options actually changed
             if [[ "$original_options_names" != "$new_options_names" ]]; then
                 echo "Propagate $current_key: Names reduced from [$original_options_names] to [$new_options_names], Chars: [$new_options_chars]" >> "$DEBUG_LOG_FILE"
                 grid[$current_key]="$new_options_names"
                 possibilities[$current_key]="$new_options_chars" # Update chars

                 # Fix: Add neighbors to queue with correct coordinate calculations
                 for dir2 in "${directions[@]}"; do
                     local nny; local nnx
                     case "$dir2" in 
                         left) nny="$cy"; nnx=$((cx-1)) ;;
                         right) nny="$cy"; nnx=$((cx+1)) ;;
                         up) nny=$((cy-1)); nnx="$cx" ;; # Fix: Corrected typo here from nx to nnx
                         down) nny=$((cy+1)); nnx="$cx" ;; # Fix: Corrected typo here from nx to nnx
                     esac
                     local nnkey="$nny,$nnx"
                     
                     # Only add uncollapsed cells within bounds
                     if (( nny >= 0 && nny < ROWS && nnx >= 0 && nnx < COLS )) && [[ "${collapsed[$nnkey]:-0}" == "0" ]]; then
                         # Check if already in queue
                         local nn_in_queue=0
                         for item in "${queue[@]}"; do 
                             [[ "$item" == "$nnkey" ]] && { nn_in_queue=1; break; }
                         done
                         # Only add if not already in queue 
                         [[ $nn_in_queue -eq 0 ]] && [[ ! -v processed_in_wave["$nnkey"] ]] && queue+=("$nnkey")
                     fi
                 done
             fi
        fi
        
        # If down to only one option, consider it collapsed
        if (( ${#surviving_names_arr[@]} == 1 )); then
            collapsed[$current_key]=1
            echo "Auto-collapsed $current_key to '${surviving_names_arr[0]}'" >> "$DEBUG_LOG_FILE"
        fi
    done
    
    # Warn if reached max iterations
    if (( processed_count >= max_processed )); then
        echo "ERROR (propagate): Exceeded max steps." >> "$DEBUG_LOG_FILE"
        STATUS_MESSAGE="Warning: Reached max propagation steps."
    fi
}

# ───── Engine-Called Functions ─────

# Initialize connection rules (Using TILE NAMES)
init_rules() {
    rules=() # Clear global rules
    echo "INFO (grid2.sh): Initializing 2x2 Tube Network rules (using tile names)..." >> "$DEBUG_LOG_FILE"
    
    # Define which tiles have openings in each direction 
    local opens_right="STRAIGHT_H BEND_NE BEND_SE CROSS T_NORTH T_SOUTH T_WEST"
    local opens_left="STRAIGHT_H BEND_NW BEND_SW CROSS T_NORTH T_SOUTH T_EAST"
    local opens_top="STRAIGHT_V BEND_NW BEND_NE CROSS T_EAST T_WEST T_SOUTH"
    local opens_bottom="STRAIGHT_V BEND_SW BEND_SE CROSS T_EAST T_WEST T_NORTH"
    
    # Set up rules - which tiles can connect in each direction
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
    
    # Ensure all rule keys are initialized (even if empty)
    local -a all_tile_names=("${SYMBOLS[@]}")
    local -a all_dirs=("left" "right" "up" "down")
    for name in "${all_tile_names[@]}"; do
        for dir in "${all_dirs[@]}"; do
            local rule_key="${name}_${dir}"
            printf -v rules["$rule_key"] '%s' "${rules[$rule_key]:-}"
        done
    done
    
    echo "INFO (grid2.sh): 2x2 Tube Network rules initialized." >> "$DEBUG_LOG_FILE"
}

# Initialize grid - Use Random Seed & Simpler Tile
init_grid() {
    grid=(); possibilities=(); collapsed=()
    local all_symbols_names="${SYMBOLS[*]}" # String of names
    local all_symbols_chars=$(convert_names_to_chars "$all_symbols_names") # String of chars

    echo "INFO (grid2.sh): Initializing grid (${ROWS}x${COLS}). Grid=Names, Possibilities=Chars." >> "$DEBUG_LOG_FILE"
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            grid[$key]="$all_symbols_names"
            possibilities[$key]="$all_symbols_chars"
            collapsed[$key]=0
        done
    done

    # Modified: Randomly choose seed type (preferring simpler) and location
    local seed_x=$((RANDOM % COLS))
    local seed_y=$((RANDOM % ROWS))
    local seed_key="$seed_y,$seed_x"

    # Select a simpler piece type (straight or corner) to start
    local seed_options=("STRAIGHT_H" "STRAIGHT_V" "BEND_NE" "BEND_NW" "BEND_SE" "BEND_SW")
    local seed_index=$((RANDOM % ${#seed_options[@]}))
    local seed_name="${seed_options[$seed_index]}"
    local seed_char="${TILE_NAME_TO_CHAR[$seed_name]}"

    if [[ -v grid["$seed_key"] ]]; then
        grid[$seed_key]="$seed_name"
        possibilities[$seed_key]="$seed_char"
        collapsed[$seed_key]=1
        echo "INFO (grid2.sh): Seeded $seed_key. Grid='$seed_name', Poss='$seed_char'." >> "$DEBUG_LOG_FILE"
        propagate "$seed_y" "$seed_x"
    else
        echo "WARN (grid2.sh): Seed key $seed_key invalid." >> "$DEBUG_LOG_FILE"
    fi

    # Check for any initial contradictions
    local contradictions=0
    for key in "${!grid[@]}"; do
        if [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]]; then
            contradictions=1
            break
        fi
    done
    
    if [[ $contradictions -eq 1 ]]; then
        echo "ERROR (grid2.sh): Contradiction after init!" >> "$DEBUG_LOG_FILE"
        STATUS_MESSAGE="Error: Initial contradiction."
    else
        echo "INFO (grid2.sh): Grid init OK." >> "$DEBUG_LOG_FILE"
    fi
}

# update_algorithm - Use Weighted Selection
update_algorithm() {
    local min_entropy=99999
    local -a candidates=()
    local potential_contradiction=0
    local all_cells_collapsed_check=1

    # Find cell with minimum entropy
    for key in "${!collapsed[@]}"; do
        if [[ "${collapsed[$key]:-0}" == "0" ]]; then
            all_cells_collapsed_check=0
            local current_options_names="${grid[$key]-}"
            
            # Skip error cells
            if [[ "$current_options_names" == "$ERROR_SYMBOL" ]]; then
                potential_contradiction=1
                [[ "${collapsed[$key]}" == "0" ]] && collapsed[$key]=1
                continue
            fi
            
            # Count options and check for contradictions
            local -a opts_arr=($current_options_names)
            local entropy=${#opts_arr[@]}
            
            if (( entropy == 0 )); then
                echo "!!!!!! CONTRADICTION in update for $key. Names empty." >> "$DEBUG_LOG_FILE"
                potential_contradiction=1
                grid[$key]="$ERROR_SYMBOL"
                possibilities[$key]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"
                collapsed[$key]=1
                continue
            fi
            
            # Track cells with minimum entropy
            if (( entropy < min_entropy )); then
                min_entropy=$entropy
                candidates=("$key")
            elif (( entropy == min_entropy )); then
                local exists=0
                for cand in "${candidates[@]}"; do
                    [[ "$cand" == "$key" ]] && { exists=1; break; }
                done
                [[ $exists -eq 0 ]] && candidates+=("$key")
            fi
        fi
    done

    # Check if all cells are collapsed
    if [[ $all_cells_collapsed_check -eq 1 ]]; then
        local final_contradiction=0
        for key in "${!grid[@]}"; do
            if [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]]; then
                final_contradiction=1
                break
            fi
        done
        
        if [[ $final_contradiction -eq 1 ]]; then
            STATUS_MESSAGE="WFC Complete with some contradictions."
        else
            STATUS_MESSAGE="WFC Complete!"
        fi
        return 1
    fi
    
    # No valid candidates to collapse
    if (( ${#candidates[@]} == 0 )); then
        if [[ $potential_contradiction -eq 1 ]]; then
            STATUS_MESSAGE="WFC Error: Contradiction found."
        else
            STATUS_MESSAGE="WFC Error: No cells to collapse."
        fi
        return 1
    fi

    # Randomly choose a cell with minimum entropy
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}";
    local y="${pick%,*}";
    local x="${pick#*,}"
    local options_names="${grid[$pick]}"
    local -a options_arr=($options_names)

    if (( ${#options_arr[@]} == 0 )); then
        STATUS_MESSAGE="WFC Error: Selected cell has no options!"
        grid[$pick]="$ERROR_SYMBOL"
        possibilities[$pick]="${TILE_NAME_TO_CHAR[$ERROR_SYMBOL]}"
        collapsed[$pick]=1
        return 1
    fi

    # --- Modified: Weighted Random Selection ---
    local total_weight=0
    local -a cumulative_weights=()
    local option # loop variable
    
    # Calculate total weight and cumulative weights
    for option in "${options_arr[@]}"; do
        # Use default weight of 1 if not specified
        local weight=${TILE_WEIGHTS[$option]:-1} 
        # Use bc for floating point addition
        total_weight=$(echo "$total_weight + $weight" | bc -l) 
        cumulative_weights+=("$total_weight")
    done
    
    local chosen_name=""
    if (( $(echo "$total_weight > 0" | bc -l) )); then
        # Generate random float between 0 and total_weight
        local random_value=$(echo "scale=10; $RANDOM / 32767 * $total_weight" | bc -l) 
        local chosen_index=0
        
        # Find the chosen index based on random value
        for ((i=0; i<${#cumulative_weights[@]}; i++)); do
            # Use bc for floating point comparison
            if (( $(echo "$random_value <= ${cumulative_weights[$i]}" | bc -l) )); then
                chosen_index=$i
                break
            fi
        done
        chosen_name="${options_arr[$chosen_index]}"
    else
        # Fallback if total weight is zero (shouldn't happen with default 1)
         echo "WARN (grid2.sh Update): Total weight is zero for $pick, choosing random." >> "$DEBUG_LOG_FILE"
         chosen_name="${options_arr[$((RANDOM % ${#options_arr[@]}))]}"
    fi
    # --- End Weighted Selection Modification ---

    local chosen_char="${TILE_NAME_TO_CHAR[$chosen_name]}"
    grid[$pick]="$chosen_name"
    possibilities[$pick]="$chosen_char"
    collapsed[$pick]=1

    echo "DEBUG (grid2.sh Update): Collapsed $pick to name '$chosen_name' (char '$chosen_char', Entropy $min_entropy)." >> "$DEBUG_LOG_FILE"

    # Propagate the constraints
    propagate "$y" "$x"
    
    # Update status message with progress
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do
        [[ "${collapsed[$k]:-0}" == "1" ]] && ((collapsed_count++))
    done
    local total_cells=$((ROWS * COLS))
    STATUS_MESSAGE="Collapsed $pick ('$chosen_name') | $collapsed_count/$total_cells"
    
    return 0
}

# End of grid2.sh
