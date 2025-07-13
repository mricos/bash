#!/usr/bin/env bash

# WFC Algorithm Implementation (Tube Network Theme) - REVERTED
# Designed to be sourced and controlled by simple_engine.sh

# ───── Engine-Expected Variables ─────
# These are declared globally in simple_engine.sh and populated here.
# declare -gA grid
# declare -gA possibilities
# declare -gA collapsed
# declare -gA rules
# declare -ga SYMBOLS
# declare -ga PAGES

# Tube/Pipe Symbols
export SYMBOLS=("═" "║" "╔" "╗" "╚" "╝" "╬" "╩" "╠" "╦" "╣")
export PAGES=(
    "WFC: Tube Network Theme
---------------------------
Algorithm based on Wave
Function Collapse using the
Minimum Entropy heuristic.

Generates interconnected pipe
patterns using heavy box
drawing and T-junctions.
"
    "WFC Rules: Tube Theme
---------------------------
Defines which pipe symbols
can connect based on open
ends matching.

e.g., '═' (horizontal) must
connect to pieces with openings
on their left/right.
"
    "WFC Implementation Notes
---------------------------
- Uses associative arrays for grid state.
- Entropy = number of valid symbols.
- Propagation uses a queue.
- Error symbol ' ' indicates contradiction.
"
)
ERROR_SYMBOL=" "

# --- ASCII Name Mapping for Rule Keys ---
declare -gA SYMBOL_TO_NAME
SYMBOL_TO_NAME["═"]="PIPE_H"
SYMBOL_TO_NAME["║"]="PIPE_V"
SYMBOL_TO_NAME["╔"]="CORNER_TL"
SYMBOL_TO_NAME["╗"]="CORNER_TR"
SYMBOL_TO_NAME["╚"]="CORNER_BL"
SYMBOL_TO_NAME["╝"]="CORNER_BR"
SYMBOL_TO_NAME["╬"]="CROSS"
SYMBOL_TO_NAME["╩"]="T_UP"
SYMBOL_TO_NAME["╠"]="T_RIGHT"
SYMBOL_TO_NAME["╦"]="T_DOWN"
SYMBOL_TO_NAME["╣"]="T_LEFT"

# ───── Helper Functions (Internal to this script) ─────

# Function to filter the current options of a cell based on allowed neighbors
# (Used by propagate)
filter_options() {
    local current_options_str="$1" # Space-separated string of current options
    local allowed_options_str="$2" # Space-separated string of allowed options
    local result="" # String to store the filtered options

    # Convert current options string to an array
    local -a current_options=($current_options_str)

    # Iterate through current options
    for opt in "${current_options[@]}"; do
        # Check if the option is present in the allowed options string
        if [[ " $allowed_options_str " == *" $opt "* ]]; then
            result+="$opt "
        fi
    done
    # Return the filtered options (remove trailing space)
    echo "${result% }"
}

# Function to propagate constraints to neighboring cells
# Modifies the global 'grid' and 'possibilities' arrays
propagate() {
    local y="$1"
    local x="$2"
    # The symbol that was just placed at y,x is not directly needed here,
    # as we derive constraints from the *remaining* possibilities of neighbors.
    # We start propagation check from the neighbours of the collapsed cell.

    local -a directions=("left" "right" "up" "down")
    local -a queue=() # Queue for cells whose options *might* need re-evaluation due to changes

    # Initial neighbors to check (adjacent to the collapsed cell y,x)
    for dir in "${directions[@]}"; do
         local ny; local nx
         case "$dir" in
            left)  ny="$y"; nx=$((x - 1)); ;;
            right) ny="$y"; nx=$((x + 1)); ;;
            up)    ny=$((y - 1)); nx="$x"; ;;
            down)  ny=$((y + 1)); nx="$x"; ;;
         esac
         local nkey="$ny,$nx"
         if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && [[ "${collapsed[$nkey]}" == "0" ]]; then
             queue+=("$nkey")
         fi
    done

    local -A processed_in_wave # Track cells added to queue in this wave to prevent loops

    while (( ${#queue[@]} > 0 )); do
        local current_key="${queue[0]}"
        queue=("${queue[@]:1}")

        # Avoid reprocessing the same cell multiple times within one propagation wave
        if [[ -v processed_in_wave["$current_key"] ]]; then continue; fi
        processed_in_wave["$current_key"]=1

        local cy="${current_key%,*}"
        local cx="${current_key#*,}"
        local original_options="${grid[$current_key]}" # Keep original for comparison

        # Store the symbols that *could* be placed in the current cell based on its *already collapsed* neighbours
        local valid_options_for_current=""

        # Iterate through potential symbols for the current cell
        local -a potential_symbols=($original_options)
        for potential_sym in "${potential_symbols[@]}"; do
            local possible=1 # Assume this symbol is possible initially
            # Check against *all* neighbors (especially collapsed ones)
            for dir in "${directions[@]}"; do
                local ny; local nx; local opposite_dir
                case "$dir" in
                    left)  ny="$cy"; nx=$((cx - 1)); opposite_dir="right"; ;;
                    right) ny="$cy"; nx=$((cx + 1)); opposite_dir="left"; ;;
                    up)    ny=$((cy - 1)); nx="$cx"; opposite_dir="down"; ;;
                    down)  ny=$((cy + 1)); nx="$cx"; opposite_dir="up"; ;;
                esac
                local nkey="$ny,$nx"

                # Check bounds
                if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then continue; fi

                # Get the fixed symbol of the neighbor *if* it's collapsed
                local neighbor_symbol=""
                if [[ "${collapsed[$nkey]}" == "1" ]]; then
                     neighbor_symbol="${grid[$nkey]}"
                     # Handle case where neighbor is an error symbol
                     if [[ "$neighbor_symbol" == "$ERROR_SYMBOL" ]]; then continue; fi
                else
                     continue # Only check constraint against *collapsed* neighbours
                fi

                # --- Rule Lookup using ASCII Name --- 
                # Get the ASCII name for the neighbor's symbol
                local neighbor_name="${SYMBOL_TO_NAME[$neighbor_symbol]}"
                if [[ -z "$neighbor_name" ]]; then
                    # Should not happen if SYMBOL_TO_NAME is complete
                    echo "ERROR (propagate): Unknown symbol '$neighbor_symbol' at $nkey" >&2
                    possible=0; break
                fi
                # Construct the rule key using the ASCII name
                local rule_key="${neighbor_name}_${opposite_dir}"
                local allowed_by_neighbor="${rules[$rule_key]}"
                # --- End Rule Lookup --- 

                # If the potential_sym for the current cell is NOT allowed by this collapsed neighbor
                if [[ -z "$allowed_by_neighbor" || " ${allowed_by_neighbor} " != *" ${potential_sym} "* ]]; then
                    possible=0 # This potential_sym is impossible due to this neighbor
                    break # No need to check other neighbors for this potential_sym
                fi
            done # End neighbor check for potential_sym

            if [[ $possible -eq 1 ]]; then
                valid_options_for_current+="$potential_sym "
            fi
        done # End loop through potential symbols

        local new_options="${valid_options_for_current% }" # Remove trailing space

        # Update if options have changed
        if [[ "$original_options" != "$new_options" ]]; then
            grid[$current_key]="$new_options"
            possibilities[$current_key]="$new_options" # Keep possibilities synced for rendering

            if [[ -z "$new_options" ]]; then
                # Contradiction! Mark cell and stop further propagation from here
                grid[$current_key]="$ERROR_SYMBOL"
                possibilities[$current_key]="$ERROR_SYMBOL"
                collapsed[$current_key]=1 # Mark as collapsed (with error)
                # Engine's status message will reflect error on next update_algorithm run
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
                     if (( nny >= 0 && nny < ROWS && nnx >= 0 && nnx < COLS )) && \
                        [[ "${collapsed[$nnkey]}" == "0" && ! -v processed_in_wave["$nnkey"] ]]; then
                         queue+=("$nnkey")
                     fi
                 done
            fi
        fi # End if options changed
    done # End while queue not empty
}

# ───── Engine-Called Functions ─────

# Initialize connection rules (Tube Network Theme)
init_rules() {
    unset rules # Explicitly unset before declaring
    declare -gA rules # Ensure rules is declared as a global associative array
    echo "INFO (wfc.sh): Initializing Tube Network rules..." >> "$LOG_FILE"

    # Allowed neighbor symbols (strings of actual symbols)
    local connects_from_right="═ ╗ ╝ ╣ ╬"
    local connects_from_left="═ ╔ ╚ ╠ ╬"
    local connects_from_bottom="║ ╚ ╝ ╩ ╬"
    local connects_from_top="║ ╔ ╗ ╦ ╬"

    # Use ASCII names for rule keys
    rules["PIPE_H_left"]="$connects_from_right"
    rules["PIPE_H_right"]="$connects_from_left"
    rules["PIPE_H_up"]=""
    rules["PIPE_H_down"]=""

    rules["PIPE_V_left"]=""
    rules["PIPE_V_right"]=""
    rules["PIPE_V_up"]="$connects_from_bottom"
    rules["PIPE_V_down"]="$connects_from_top"

    rules["CORNER_TL_left"]=""
    rules["CORNER_TL_right"]="$connects_from_left"
    rules["CORNER_TL_up"]=""
    rules["CORNER_TL_down"]="$connects_from_top"

    rules["CORNER_TR_left"]="$connects_from_right"
    rules["CORNER_TR_right"]=""
    rules["CORNER_TR_up"]=""
    rules["CORNER_TR_down"]="$connects_from_top"

    rules["CORNER_BL_left"]=""
    rules["CORNER_BL_right"]="$connects_from_left"
    rules["CORNER_BL_up"]="$connects_from_bottom"
    rules["CORNER_BL_down"]=""

    rules["CORNER_BR_left"]="$connects_from_right"
    rules["CORNER_BR_right"]=""
    rules["CORNER_BR_up"]="$connects_from_bottom"
    rules["CORNER_BR_down"]=""

    rules["T_DOWN_left"]="$connects_from_right"
    rules["T_DOWN_right"]="$connects_from_left"
    rules["T_DOWN_up"]=""
    rules["T_DOWN_down"]="$connects_from_top"

    rules["T_UP_left"]="$connects_from_right"
    rules["T_UP_right"]="$connects_from_left"
    rules["T_UP_up"]="$connects_from_bottom"
    rules["T_UP_down"]=""

    rules["T_RIGHT_left"]=""
    rules["T_RIGHT_right"]="$connects_from_left"
    rules["T_RIGHT_up"]="$connects_from_bottom"
    rules["T_RIGHT_down"]="$connects_from_top"

    rules["T_LEFT_left"]="$connects_from_right"
    rules["T_LEFT_right"]=""
    rules["T_LEFT_up"]="$connects_from_bottom"
    rules["T_LEFT_down"]="$connects_from_top"

    rules["CROSS_left"]="$connects_from_right"
    rules["CROSS_right"]="$connects_from_left"
    rules["CROSS_up"]="$connects_from_bottom"
    rules["CROSS_down"]="$connects_from_top"

    # Ensure all defined ASCII names have entries for all directions (even if empty)
    local -a all_dirs=("left" "right" "up" "down")
    local name
    for name in "${SYMBOL_TO_NAME[@]}"; do # Iterate through the ASCII names (values of the map)
        for dir in "${all_dirs[@]}"; do
            local rule_key="${name}_${dir}"
            [[ -v rules["$rule_key"] ]] || rules["$rule_key"]=""
        done
    done
    echo "INFO (wfc.sh): Tube Network rules initialized using ASCII keys." >> "$LOG_FILE"
}

# Initialize grid with Shipibo pattern guidance
init_grid() {
    # Explicitly clear global arrays
    grid=()
    possibilities=()
    collapsed=()
    local all_symbols_str="${SYMBOLS[*]}"

    echo "INFO (wfc.sh - reverted): Initializing grid (${ROWS}x${COLS})." >> "$LOG_FILE"

    for ((y = 0; y < ROWS; y++)); do
        for ((x = 0; x < COLS; x++)); do
            local key="$y,$x"
            # Set initial possible symbols for the cell
            grid[$key]="$all_symbols_str"
            possibilities[$key]="$all_symbols_str"
            # Mark cell as not collapsed
            collapsed[$key]=0
        done
    done

    # --- Seed the grid (Simple Center Seed) ---
    local seed_y=$((ROWS / 2))
    local seed_x=$((COLS / 2))
    local seed_key="$seed_y,$seed_x"

    if [[ -v grid["$seed_key"] ]]; then
        local -a seed_options=(${grid[$seed_key]})
        if (( ${#seed_options[@]} > 0 )); then
            # Pick a random valid starting symbol
            local seed_symbol="${seed_options[$((RANDOM % ${#seed_options[@]}))]}"
            grid[$seed_key]="$seed_symbol"
            possibilities[$seed_key]="$seed_symbol"
            collapsed[$seed_key]=1
            echo "INFO (wfc.sh - reverted): Seeded grid at $seed_key with '$seed_symbol'." >> "$LOG_FILE"
            # Propagate from the seed immediately
            propagate "$seed_y" "$seed_x"
        else
             echo "WARN (wfc.sh - reverted): Cannot seed at $seed_key, no initial options?" >> "$LOG_FILE"
        fi
    else
        echo "WARN (wfc.sh - reverted): Seed key $seed_key invalid." >> "$LOG_FILE"
    fi

    echo "INFO (wfc.sh - reverted): Grid initialized and seeded. ${#grid[@]} cells." >> "$LOG_FILE"
}

# Modify update_algorithm to use the Shipibo biasing
update_algorithm() {
    local min_entropy=9999
    local -a candidates=()
    local potential_contradiction=0
    local all_cells_collapsed_check=1 # Assume true initially

    # --- Find cell(s) with minimum entropy (original logic) ---
    # Check ALL uncollapsed cells
    for key in "${!collapsed[@]}"; do
        if [[ "${collapsed[$key]}" == "0" ]]; then
            all_cells_collapsed_check=0 # Found an uncollapsed cell
            local current_options="${grid[$key]}"

            # Check for contradiction
            if [[ -z "$current_options" || "$current_options" == "$ERROR_SYMBOL" ]]; then
                potential_contradiction=1
                if [[ "$current_options" != "$ERROR_SYMBOL" ]]; then
                    grid[$key]="$ERROR_SYMBOL"
                    possibilities[$key]="$ERROR_SYMBOL"
                    collapsed[$key]=1 # Mark error cell as collapsed
                fi
                 echo "WARN (wfc.sh - reverted): Cell $key is contradiction." >> "$LOG_FILE"
                continue # Don't consider this cell for minimum entropy
            fi

            # Calculate entropy
            local -a opts=($current_options)
            local entropy=${#opts[@]}

            if (( entropy > 0 )); then
                if (( entropy < min_entropy )); then
                    min_entropy=$entropy
                    candidates=("$key") # New minimum found, reset candidates
                elif (( entropy == min_entropy )); then
                    candidates+=("$key") # Add to candidates with same minimum
                fi
            fi
        fi
    done

    # --- Check Results ---
    if [[ $all_cells_collapsed_check -eq 1 ]]; then
        STATUS_MESSAGE="WFC Complete! (All collapsed)"
        echo "INFO (wfc.sh - reverted): All cells collapsed." >> "$LOG_FILE"
        return 1 # Signal completion
    fi

    if (( ${#candidates[@]} == 0 )); then
        if [[ $potential_contradiction -eq 1 ]]; then
            STATUS_MESSAGE="WFC Error: Contradiction detected."
            echo "ERROR (wfc.sh - reverted): Contradiction detected (no candidates with >0 entropy)." >> "$LOG_FILE"
        else
            # This case happens if all remaining cells have 0 entropy but weren't marked as errors
            STATUS_MESSAGE="WFC Error: No candidates found (all remaining cells have 0 entropy)."
            echo "ERROR (wfc.sh - reverted): No candidates found, likely stuck." >> "$LOG_FILE"
            # Mark remaining uncollapsed as errors? Or just stop? Let's stop.
        fi
        return 1 # Signal error/stuck
    fi

    # --- Collapse Chosen Candidate (Random Pick) ---
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options_str="${grid[$pick]}"
    local -a options=($options_str)

    if (( ${#options[@]} == 0 )); then
        # This should ideally be caught earlier, but as a safeguard
        STATUS_MESSAGE="WFC Error: Picked candidate $pick has no options unexpectedly."
        echo "ERROR (wfc.sh - reverted): Candidate $pick '$options_str' zero options on collapse." >> "$LOG_FILE"
        grid[$pick]="$ERROR_SYMBOL"
        possibilities[$pick]="$ERROR_SYMBOL"
        collapsed[$pick]=1
        return 1 # Signal error
    fi

    # Select random symbol from the possibilities
    local symbol="${options[$((RANDOM % ${#options[@]}))]}"

    # Update the grid and mark as collapsed
    grid[$pick]="$symbol"
    possibilities[$pick]="$symbol" # Keep possibilities synced
    collapsed[$pick]=1
    echo "DEBUG (wfc.sh - reverted): Collapsed $pick to '$symbol' (Entropy $min_entropy)." >> "$LOG_FILE"

    # Propagate the constraints
    propagate "$y" "$x"

    # Update status message
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    local total_cells=$((ROWS * COLS))
    STATUS_MESSAGE="Collapsed $pick ('$symbol') | $collapsed_count/$total_cells"

    return 0 # Success, continue
}

# No main loop, rendering, or input handling needed here.
# The engine script (simple_engine.sh) handles that.
