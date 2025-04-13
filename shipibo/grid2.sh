#!/bin/bash
set -x
# grid2.sh - WFC with 2x2 Tiles

# Define rendering strings (similar to claude-2x2, simplified without color for now)
# These will be needed by the rendering engine (simple_engine.sh)
declare -gA TILE_TOPS
declare -gA TILE_BOTS

TILE_TOPS["STRAIGHT_H"]="═══ ═══"
TILE_BOTS["STRAIGHT_H"]="═══ ═══"
TILE_TOPS["STRAIGHT_V"]=" ║   ║ "
TILE_BOTS["STRAIGHT_V"]=" ║   ║ "
TILE_TOPS["BEND_NE"]="    ║ "
TILE_BOTS["BEND_NE"]="═══ ═╝ "
TILE_TOPS["BEND_NW"]=" ║     "
TILE_BOTS["BEND_NW"]=" ╚═ ═══"
TILE_TOPS["BEND_SE"]="═══ ═╗ "
TILE_BOTS["BEND_SE"]="    ║ "
TILE_TOPS["BEND_SW"]=" ╔═ ═══"
TILE_BOTS["BEND_SW"]=" ║     "
TILE_TOPS["CROSS"]=" ║   ║ " # Using vertical bars for cross, consistent look
TILE_TOPS["CROSS"]="═╬═ ═╬═" # Needs careful thought on representation
TILE_TOPS["T_NORTH"]=" ║   ║ "
TILE_TOPS["T_NORTH"]="═╩═ ═══"
TILE_TOPS["T_EAST"]=" ║     "
TILE_TOPS["T_EAST"]=" ╠═ ═══"
TILE_TOPS["T_SOUTH"]="═╦═ ═══"
TILE_TOPS["T_SOUTH"]=" ║   ║ "
TILE_TOPS["T_WEST"]="    ║ "
TILE_TOPS["T_WEST"]="═══ ═╣ "
# TILE_TOPS["EMPTY"]="       " # Omitting EMPTY for now
# TILE_BOTS["EMPTY"]="       "

# Update SYMBOLS array to use names
export SYMBOLS=("STRAIGHT_H" "STRAIGHT_V" "BEND_NE" "BEND_NW" "BEND_SE" "BEND_SW" "CROSS" "T_NORTH" "T_EAST" "T_SOUTH" "T_WEST")

# Define ERROR_SYMBOL for contradictions
ERROR_SYMBOL="ERROR"

# Refactored PAGES array using multi-line strings
PAGES=(
"WFC: 2x2 Tube Network Theme
---------------------------
Generates interconnected pipe
patterns using 2x2 tiles based
on Wave Function Collapse."

"WFC Rules: 2x2 Tube Theme
---------------------------
Defines which 2x2 pipe tiles
can connect based on matching
openings on adjacent edges."

"WFC Implementation Notes
---------------------------
- Uses tile names internally.
- Engine render modified.
- Propagation checks tile compatibility."
)
export PAGES # Export for the engine


# ───── Helper Functions ─────

# Function to propagate constraints to neighboring cells
# Modifies the global 'grid' and 'possibilities' arrays
propagate() {
    local y="$1"
    local x="$2"
    local -a queue=() # Queue for cells whose options *might* need re-evaluation

    # Initial neighbors to check (adjacent to the collapsed cell y,x)
    local -a directions=("left" "right" "up" "down")
    for dir in "${directions[@]}"; do
         local ny; local nx
         case "$dir" in
            left)  ny="$y"; nx=$((x - 1)); ;;
            right) ny="$y"; nx=$((x + 1)); ;;
            up)    ny=$((y - 1)); nx="$x"; ;;
            down)  ny=$((y + 1)); nx="$x"; ;;
         esac
         local nkey="$ny,$nx"
         # Add neighbor to queue if it's within bounds and not already collapsed
         if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && [[ "${collapsed[$nkey]:-0}" == "0" ]]; then
             # Check if already in queue to avoid duplicates (simple check)
             local in_queue=0
             for item in "${queue[@]}"; do [[ "$item" == "$nkey" ]] && { in_queue=1; break; }; done
             [[ $in_queue -eq 0 ]] && queue+=("$nkey")
         fi
    done

    local -A processed_in_wave # Track cells processed in this *entire* propagation wave to prevent infinite loops

    local processed_count=0 # Debug counter
    local max_processed=10000 # Limit processing steps to prevent runaway loops

    while (( ${#queue[@]} > 0 && processed_count < max_processed )); do
        ((processed_count++))
        local current_key="${queue[0]}"
        queue=("${queue[@]:1}") # Dequeue

        # Skip if already processed *in this wave*
        if [[ -v processed_in_wave["$current_key"] ]]; then
            # echo "DEBUG (propagate): Skipping $current_key (already processed in wave)" >> "$DEBUG_LOG_FILE"
            continue
        fi
        processed_in_wave["$current_key"]=1
        # echo "DEBUG (propagate): Processing $current_key (${#queue[@]} left in queue)" >> "$DEBUG_LOG_FILE"


        local cy="${current_key%,*}"
        local cx="${current_key#*,}"
        # Ensure grid entry exists before accessing
        local original_options="${grid[$current_key]-}" # Space-separated tile names
        local changed=0 # Flag to track if options changed

        # If original options were already ERROR, skip (shouldn't happen if enqueue logic is right)
        if [[ "$original_options" == "$ERROR_SYMBOL" ]]; then
             echo "WARN (propagate): Trying to process cell $current_key already marked as ERROR." >> "$DEBUG_LOG_FILE"
             continue
        fi

        # --- Filter current cell's options based on *all* neighbors ---
        local valid_options_for_current=""
        # Ensure array is created even if original_options is empty
        local -a current_symbols_arr=($original_options)

        # Handle case where current cell somehow has no options before filtering
        if [[ ${#current_symbols_arr[@]} -eq 0 && "${collapsed[$current_key]:-0}" == "0" ]]; then
             echo "WARN (propagate): Cell $current_key has no options before filtering, marking ERROR." >> "$DEBUG_LOG_FILE"
             grid[$current_key]="$ERROR_SYMBOL"
             possibilities[$current_key]="$ERROR_SYMBOL"
             collapsed[$current_key]=1 # Mark as collapsed (with error)
             changed=1 # Mark as changed to stop further processing here
             continue # Skip neighbor checks for this cell
        fi

        echo "DEBUG (propagate): Processing $current_key. Original opts: [${original_options}]" >> "$DEBUG_LOG_FILE"

        for potential_sym in "${current_symbols_arr[@]}"; do
             local possible_for_all_neighbors=1 # Assume possible initially
             echo "DEBUG (propagate):   Checking potential '$potential_sym' for $current_key" >> "$DEBUG_LOG_FILE"

             # Check this potential_sym against *all* neighbors
             for dir in "${directions[@]}"; do
                 local ny; local nx; local opposite_dir
                 case "$dir" in
                    left)  ny="$cy"; nx=$((cx - 1)); opposite_dir="right"; ;;
                    right) ny="$cy"; nx=$((cx + 1)); opposite_dir="left"; ;;
                    up)    ny=$((cy - 1)); nx="$cx"; opposite_dir="down"; ;;
                    down)  ny=$((cy + 1)); nx="$cx"; opposite_dir="up"; ;;
                 esac
                 local nkey="$ny,$nx"

                 # Skip if neighbor is out of bounds
                 if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then continue; fi

                 # Get neighbor's options (could be single collapsed symbol or list)
                 # Ensure grid entry exists before accessing
                 local neighbor_options="${grid[$nkey]-}"
                 # Handle ERROR state in neighbor
                 if [[ "$neighbor_options" == "$ERROR_SYMBOL" ]]; then continue; fi

                 local -a neighbor_symbols_arr=($neighbor_options)
                 # Handle case where neighbor might have empty options (should be ERROR)
                 if [[ ${#neighbor_symbols_arr[@]} -eq 0 && "${collapsed[$nkey]:-0}" == "0" ]]; then
                      echo "WARN (propagate): Neighbor $nkey of $current_key has 0 options but isn't collapsed. Potential issue." >> "$DEBUG_LOG_FILE"
                      # We might treat this as a reason potential_sym is impossible, depending on desired strictness.
                      # For now, let's assume it doesn't restrict potential_sym.
                      continue
                 fi

                 local neighbor_allows_potential_sym=0

                 for neighbor_sym in "${neighbor_symbols_arr[@]}"; do
                     local rule_key="${neighbor_sym}_${opposite_dir}"
                     local allowed_by_this_neighbor_sym="${rules[$rule_key]-}"

                     if [[ " ${allowed_by_this_neighbor_sym} " == *" ${potential_sym} "* ]]; then
                         neighbor_allows_potential_sym=1
                         break
                     fi
                 done

                 if [[ $neighbor_allows_potential_sym -eq 0 ]]; then
                     possible_for_all_neighbors=0
                     echo "DEBUG (propagate):     '$potential_sym' rejected for $current_key by neighbor $nkey ($dir) [Neighbor opts: ${neighbor_options}]" >> "$DEBUG_LOG_FILE"
                     break
                 fi
             done # End loop through directions for potential_sym

             if [[ $possible_for_all_neighbors -eq 1 ]]; then
                 valid_options_for_current+="$potential_sym "
                 echo "DEBUG (propagate):     '$potential_sym' accepted for $current_key" >> "$DEBUG_LOG_FILE"
             fi
        done # End loop through potential symbols for current cell

        local new_options="${valid_options_for_current% }"
        echo "DEBUG (propagate): Finished $current_key. New opts: [$new_options]" >> "$DEBUG_LOG_FILE"

        # Update if options have changed
        if [[ "$original_options" != "$new_options" ]]; then
            # echo "DEBUG (propagate): Options for $current_key changed from '$original_options' to '$new_options'" >> "$DEBUG_LOG_FILE"
            changed=1
            grid[$current_key]="$new_options"
            possibilities[$current_key]="$new_options" # Keep possibilities synced

            if [[ -z "$new_options" ]]; then
                # Contradiction! Mark cell
                grid[$current_key]="$ERROR_SYMBOL"
                possibilities[$current_key]="$ERROR_SYMBOL"
                collapsed[$current_key]=1 # Mark as collapsed (with error)
                echo "WARN (grid2.sh): Contradiction at $current_key. Options became empty." >> "$DEBUG_LOG_FILE"
                # Don't enqueue neighbors of a contradicted cell
            else
                # Options reduced, enqueue *its* neighbors for re-evaluation
                 for dir in "${directions[@]}"; do
                     local nny; local nnx
                     case "$dir" in
                        left)  nny="$cy"; nnx=$((cx - 1)); ;;
                        right) nny="$cy"; nnx=$((cx + 1)); ;;
                        up)    nny=$((cy - 1)); nnx="$cx"; ;;
                        down)  nny=$((cy + 1)); nnx="$cx"; ;;
                     esac
                     local nnkey="$nny,$nnx"
                     # Add neighbor to queue if it's within bounds, not collapsed, and not already processed in this wave
                     if (( nny >= 0 && nny < ROWS && nnx >= 0 && nnx < COLS )) && \
                        [[ "${collapsed[$nnkey]:-0}" == "0" && ! -v processed_in_wave["$nnkey"] ]]; then
                           # Check if already in queue to avoid duplicates
                           local nn_in_queue=0
                           for item in "${queue[@]}"; do [[ "$item" == "$nnkey" ]] && { nn_in_queue=1; break; }; done
                           if [[ $nn_in_queue -eq 0 ]]; then
                              # echo "DEBUG (propagate): Enqueueing neighbor $nnkey due to change at $current_key" >> "$DEBUG_LOG_FILE"
                              queue+=("$nnkey")
                           fi
                     fi
                 done
            fi
        fi # End if options changed
    done # End while queue not empty

    if (( processed_count >= max_processed )); then
         echo "ERROR (propagate): Exceeded max processing steps ($max_processed). Possible infinite loop." >> "$DEBUG_LOG_FILE"
         STATUS_MESSAGE="Error: Propagation loop detected."
         # Maybe mark state as errored? For now, just log and stop propagation.
    fi
}


# ───── Engine-Called Functions ─────

# Initialize connection rules (2x2 Tube Network Theme)
init_rules() {
    # Add specific log at top of function
    echo "DEBUG (grid2.sh): init_rules starting with PAGES = ${#PAGES[@]} elements" >> "$DEBUG_LOG_FILE"
    
    rules=() # Clear global rules
    # Use grid2.sh in log message
    echo "INFO (grid2.sh): Initializing 2x2 Tube Network rules..." >> "$DEBUG_LOG_FILE"

    # Define which tiles have openings on each side
    local opens_right="STRAIGHT_H BEND_NE BEND_SE CROSS T_NORTH T_SOUTH T_WEST"
    local opens_left="STRAIGHT_H BEND_NW BEND_SW CROSS T_NORTH T_SOUTH T_EAST"
    local opens_top="STRAIGHT_V BEND_NW BEND_NE CROSS T_EAST T_WEST T_SOUTH"
    local opens_bottom="STRAIGHT_V BEND_SW BEND_SE CROSS T_EAST T_WEST T_NORTH"

    # For a tile TILE, rules["TILE_left"] lists tiles that can be placed TO ITS LEFT
    # (meaning the neighbor must have an opening on its RIGHT side)
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

    # Ensure all defined symbols have entries for all directions (even if empty)
    local -a all_dirs=("left" "right" "up" "down")
    for sym in "${SYMBOLS[@]}"; do
        for dir in "${all_dirs[@]}"; do
            local rule_key="${sym}_${dir}"
            printf -v rules["$rule_key"] '%s' "${rules[$rule_key]:-}" # Safely handle empty/unset
        done
    done
    echo "INFO (grid2.sh): 2x2 Tube Network rules initialized." >> "$DEBUG_LOG_FILE"
}

# Initialize grid with all possibilities and seed a starting tile
init_grid() {
    # Explicitly clear global arrays (already done by engine, but good practice)
    grid=()
    possibilities=()
    collapsed=()
    local all_symbols_str="${SYMBOLS[*]}" # Space-separated list of all tile names

    echo "INFO (grid2.sh): Initializing grid (${ROWS}x${COLS})." >> "$DEBUG_LOG_FILE"

    for ((y = 0; y < ROWS; y++)); do
        for ((x = 0; x < COLS; x++)); do
            local key="$y,$x"
            grid[$key]="$all_symbols_str"
            possibilities[$key]="$all_symbols_str"
            collapsed[$key]=0
        done
    done

    # --- Seed the grid (Simple Center Seed) ---
    local seed_y=$((ROWS / 2))
    local seed_x=$((COLS / 2))
    local seed_key="$seed_y,$seed_x"

    if [[ -v grid["$seed_key"] ]]; then
        local -a seed_options=($all_symbols_str) # Start with all symbols as options for seed
        if (( ${#seed_options[@]} > 0 )); then
            # Pick a random valid starting symbol (any symbol is valid initially)
            local seed_symbol="${seed_options[$((RANDOM % ${#seed_options[@]}))]}"
            grid[$seed_key]="$seed_symbol"
            possibilities[$seed_key]="$seed_symbol"
            collapsed[$seed_key]=1
            echo "INFO (grid2.sh): Seeded grid at $seed_key with '$seed_symbol'." >> "$DEBUG_LOG_FILE"
            # Propagate from the seed immediately
            propagate "$seed_y" "$seed_x"
        else
             echo "WARN (grid2.sh): Cannot seed at $seed_key, no initial options?" >> "$DEBUG_LOG_FILE"
        fi
    else
        echo "WARN (grid2.sh): Seed key $seed_key invalid." >> "$DEBUG_LOG_FILE"
    fi

    # Check for immediate contradictions after seeding and initial propagation
    local contradictions_after_init=0
    for key in "${!grid[@]}"; do
        if [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]]; then
             contradictions_after_init=1
             break
        fi
    done
    if [[ $contradictions_after_init -eq 1 ]]; then
         echo "ERROR (grid2.sh): Contradiction detected immediately after initialization and seeding!" >> "$DEBUG_LOG_FILE"
         STATUS_MESSAGE="Error: Initial contradiction."
         # Optionally stop execution here, but engine loop will catch it too
    else
         echo "INFO (grid2.sh): Grid initialized and seeded. ${#grid[@]} cells." >> "$DEBUG_LOG_FILE"
    fi
}

# Find cell with minimum entropy and collapse it
update_algorithm() {
    local min_entropy=99999 # Use a large number (number of symbols + 1 ok too)
    local -a candidates=()
    local potential_contradiction=0
    local all_cells_collapsed_check=1 # Assume true initially

    # --- Find cell(s) with minimum entropy ---
    for key in "${!collapsed[@]}"; do
        # Ensure collapsed state exists before checking
        if [[ "${collapsed[$key]:-0}" == "0" ]]; then
            all_cells_collapsed_check=0 # Found an uncollapsed cell
            # Ensure grid entry exists before accessing
            local current_options="${grid[$key]-}" # Space-separated tile names

            # Check for explicit contradiction marker
            if [[ "$current_options" == "$ERROR_SYMBOL" ]]; then
                potential_contradiction=1
                # Already marked as error, don't consider for entropy
                # Ensure it's marked as collapsed if it wasn't already
                [[ "${collapsed[$key]}" == "0" ]] && collapsed[$key]=1
                continue
            fi

            # Calculate entropy (number of possible tile names)
            local -a opts=($current_options)
            local entropy=${#opts[@]}

            # Check for implicit contradiction (empty options list but not marked ERROR)
            if (( entropy == 0 )); then
                # This case should ideally be caught by propagate setting ERROR_SYMBOL
                potential_contradiction=1
                grid[$key]="$ERROR_SYMBOL"
                possibilities[$key]="$ERROR_SYMBOL"
                collapsed[$key]=1 # Mark error cell as collapsed
                echo "WARN (grid2.sh Update): Cell $key found with 0 options, marking ERROR." >> "$DEBUG_LOG_FILE"
                continue # Don't consider for minimum entropy
            fi

            # Update minimum entropy and candidates
            if (( entropy < min_entropy )); then
                min_entropy=$entropy
                candidates=("$key") # New minimum found, reset candidates
            elif (( entropy == min_entropy )); then
                # Add to candidates with same minimum, avoid duplicates just in case
                local exists=0
                for cand in "${candidates[@]}"; do [[ "$cand" == "$key" ]] && { exists=1; break; }; done
                [[ $exists -eq 0 ]] && candidates+=("$key")
            fi
        fi
    done

    # --- Check Results ---
    if [[ $all_cells_collapsed_check -eq 1 ]]; then
        # Verify no contradictions remain among collapsed cells
        local final_contradiction=0
        for key in "${!grid[@]}"; do
            if [[ "${grid[$key]}" == "$ERROR_SYMBOL" ]]; then
                final_contradiction=1
                break
            fi
        done
        if [[ $final_contradiction -eq 1 ]]; then
            STATUS_MESSAGE="WFC Error: Completed with contradictions."
            echo "ERROR (grid2.sh): All cells collapsed, but contradictions remain." >> "$DEBUG_LOG_FILE"
        else
            STATUS_MESSAGE="WFC Complete! (All collapsed)"
            echo "INFO (grid2.sh): All cells collapsed successfully." >> "$DEBUG_LOG_FILE"
        fi
        return 1 # Signal completion or completed-with-error
    fi

    if (( ${#candidates[@]} == 0 )); then
        if [[ $potential_contradiction -eq 1 ]]; then
            STATUS_MESSAGE="WFC Error: Contradiction detected."
            echo "ERROR (grid2.sh): Contradiction detected (no candidates with >0 entropy)." >> "$DEBUG_LOG_FILE"
        else
            # Should not happen if entropy calculation and checks are correct
            STATUS_MESSAGE="WFC Error: No candidates found, unexpected state."
            echo "ERROR (grid2.sh): No candidates found, likely stuck or error in logic." >> "$DEBUG_LOG_FILE"
        fi
        return 1 # Signal error/stuck
    fi

    # --- Collapse Chosen Candidate (Random Pick among minimum entropy cells) ---
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options_str="${grid[$pick]}"
    local -a options=($options_str) # Array of possible tile names

    # Safeguard - should have been caught earlier if entropy was 0
    if (( ${#options[@]} == 0 )); then
        STATUS_MESSAGE="WFC Error: Picked candidate $pick has 0 options!"
        echo "ERROR (grid2.sh Update): Candidate $pick '$options_str' zero options on collapse. Should be ERROR." >> "$DEBUG_LOG_FILE"
        grid[$pick]="$ERROR_SYMBOL"
        possibilities[$pick]="$ERROR_SYMBOL"
        collapsed[$pick]=1
        return 1 # Signal error
    fi

    # Select random symbol (tile name) from the possibilities
    local chosen_symbol="${options[$((RANDOM % ${#options[@]}))]}"

    # Update the grid and mark as collapsed
    grid[$pick]="$chosen_symbol"
    possibilities[$pick]="$chosen_symbol" # Keep possibilities synced
    collapsed[$pick]=1
    echo "DEBUG (grid2.sh Update): Collapsed $pick to '$chosen_symbol' (Entropy $min_entropy)." >> "$DEBUG_LOG_FILE"

    # Propagate the constraints starting from the neighbors of the collapsed cell
    propagate "$y" "$x"

    # Update status message
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]:-0}" == "1" ]] && ((collapsed_count++)); done
    local total_cells=$((ROWS * COLS))
    STATUS_MESSAGE="Collapsed $pick ('$chosen_symbol') | $collapsed_count/$total_cells"

    return 0 # Success, continue
}

# End of grid2.sh
set +x