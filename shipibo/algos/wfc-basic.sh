#!/usr/bin/env bash

# --- WFC Algorithm: Simple T-Junctions ---

# Define the new symbol set
export SYMBOLS=("│" "─" "┌" "┐" "└" "┘" "├" "┤" "┬" "┴" "┼" " " "!") # Thin Box Chars + Space + Error Symbol
ERROR_SYMBOL="!" # Use '!' for contradictions, ensures it's in SYMBOLS

# Export documentation pages
export PAGES=(
    "WFC: Box Drawing

Generates patterns using a standard
set of thin box-drawing symbols:
│ ─ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼
Uses Wave Function Collapse with
Minimum Entropy and connection rules."
    "RULES OVERVIEW

Each symbol (e.g., ╔) has rules
defining which *other* symbols
can legally be placed adjacent
to it (Up, Down, Left, Right).
Connections must align (e.g., a
left connection requires a right
connection from the neighbor)."
    "THIN CONNECTIONS

─ connects horizontally.
│ connects vertically.
┌┐└┘ are corners.
┬┴├┤ are T-junctions.
┼ is a cross-junction.
Space allows edges/termination."
    "ALGORITHM STEPS

1. Observe: Find uncollapsed cell
   with lowest entropy (>0).
2. Collapse: Choose random valid symbol.
3. Propagate: Update neighbor options.
4. Repeat until grid full or error.
Contradictions are shown as space."
    "SYMBOLS USED

Set: │ ─ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ 
Error: Shown as Space"
)

# Rules for thin box-drawing characters
init_rules() {
    declare -gA rules # Use global rules array
    rules=()
    local LOG_PREFIX="INFO (wfc-basic-rules-v3):"
    echo "$LOG_PREFIX Initializing thin box-drawing rules..." >> "$LOG_FILE"

    # Define allowed connections for each direction FROM THE NEIGHBOR'S PERSPECTIVE.
    local allowed_right="─┘┐┤┴┼ " # Symbols allowed to the RIGHT (must connect LEFT)
    local allowed_left="─└┌├┬┼ "  # Symbols allowed to the LEFT (must connect RIGHT)
    local allowed_below="│└┘├┤┴┼ " # Symbols allowed BELOW (must connect UP)
    local allowed_above="│┌┐├┤┬┼ " # Symbols allowed ABOVE (must connect DOWN)
    local connects_all="${SYMBOLS[*]}" # All symbols including space and error symbol
    local space_or_error_only=" !"     # Only space or error allowed for non-connecting faces

    # │ (Vertical)
    rules["│_up"]="$allowed_above"
    rules["│_down"]="$allowed_below"
    rules["│_left"]="$space_or_error_only"
    rules["│_right"]="$space_or_error_only"

    # ─ (Horizontal)
    rules["─_up"]="$space_or_error_only"
    rules["─_down"]="$space_or_error_only"
    rules["─_left"]="$allowed_left"
    rules["─_right"]="$allowed_right"

    # ┌ (Top-Left)
    rules["┌_up"]="$space_or_error_only"
    rules["┌_down"]="$allowed_below"
    rules["┌_left"]="$space_or_error_only"
    rules["┌_right"]="$allowed_right"

    # ┐ (Top-Right)
    rules["┐_up"]="$space_or_error_only"
    rules["┐_down"]="$allowed_below"
    rules["┐_left"]="$allowed_left"
    rules["┐_right"]="$space_or_error_only"

    # └ (Bottom-Left)
    rules["└_up"]="$allowed_above"
    rules["└_down"]="$space_or_error_only"
    rules["└_left"]="$space_or_error_only"
    rules["└_right"]="$allowed_right"

    # ┘ (Bottom-Right)
    rules["┘_up"]="$allowed_above"
    rules["┘_down"]="$space_or_error_only"
    rules["┘_left"]="$allowed_left"
    rules["┘_right"]="$space_or_error_only"

    # ├ (Tee Right)
    rules["├_up"]="$allowed_above"
    rules["├_down"]="$allowed_below"
    rules["├_left"]="$space_or_error_only"
    rules["├_right"]="$allowed_right"

    # ┤ (Tee Left)
    rules["┤_up"]="$allowed_above"
    rules["┤_down"]="$allowed_below"
    rules["┤_left"]="$allowed_left"
    rules["┤_right"]="$space_or_error_only"

    # ┬ (Tee Down)
    rules["┬_up"]="$space_or_error_only"
    rules["┬_down"]="$allowed_below"
    rules["┬_left"]="$allowed_left"
    rules["┬_right"]="$allowed_right"

    # ┴ (Tee Up)
    rules["┴_up"]="$allowed_above"
    rules["┴_down"]="$space_or_error_only"
    rules["┴_left"]="$allowed_left"
    rules["┴_right"]="$allowed_right"

    # ┼ (Cross)
    rules["┼_up"]="$allowed_above"
    rules["┼_down"]="$allowed_below"
    rules["┼_left"]="$allowed_left"
    rules["┼_right"]="$allowed_right"

    #   (Space) - Connects freely to anything (using the original SYMBOLS list)
    rules[" _up"]="$connects_all"
    rules[" _down"]="$connects_all"
    rules[" _left"]="$connects_all"
    rules[" _right"]="$connects_all"

    # ! (Error) - Cannot connect to anything, acts like a wall
    rules["!_up"]="$space_or_error_only"    # Allow Space or Error next to Error
    rules["!_down"]="$space_or_error_only"
    rules["!_left"]="$space_or_error_only"
    rules["!_right"]="$space_or_error_only"

    echo "$LOG_PREFIX Thin box-drawing rules initialized." >> "$LOG_FILE"
}

# Function called by the lifecycle engine after sourcing the script
init_algorithm() {
    init_rules # Call the function to populate the global rules array
}

# Function to filter options (needed by propagate)
filter_options() {
    local current_options_str="$1" allowed_options_str="$2" result=""
    local -a current_options=($current_options_str)
    for opt in "${current_options[@]}"; do
        if [[ " $allowed_options_str " == *" $opt "* ]]; then result+="$opt "; fi
    done
    echo "${result% }"
}

# Propagate constraints (General WFC logic)
propagate() {
    local y_start="$1" x_start="$2" # Coordinates that triggered propagation
    local collapsed_symbol="${possibilities[$y_start,$x_start]}"
    if [[ -z "$collapsed_symbol" ]]; then return; fi # Should not happen

    local -a queue=("$y_start,$x_start")
    local -A processed_in_wave
    processed_in_wave["$y_start,$x_start"]=1

    while (( ${#queue[@]} > 0 )); do
        local current_key="${queue[0]}"; queue=("${queue[@]:1}")
        local cy="${current_key%,*}" cx="${current_key#*,}"
        local current_possibility_list="${possibilities[$current_key]}"
        if [[ -z "$current_possibility_list" ]]; then continue; fi # Already handled contradiction

        local -a directions=("left" "right" "up" "down")
        for dir in "${directions[@]}"; do
            local ny nx opposite_dir
            case "$dir" in
                left)  ny="$cy"; nx=$((cx - 1)); opposite_dir="right"; ;;
                right) ny="$cy"; nx=$((cx + 1)); opposite_dir="left"; ;;
                up)    ny=$((cy - 1)); nx="$cx"; opposite_dir="down"; ;;
                down)  ny=$((cy + 1)); nx="$cx"; opposite_dir="up"; ;;
            esac
            local nkey="$ny,$nx"

            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )) || \
               [[ "${collapsed[$nkey]}" == "1" ]]; then continue; fi

            local allowed_symbols_for_neighbor_set=""
            for current_opt in "${current_possibility_list[@]}"; do
                 local rule_key="${current_opt}_${dir}"
                 if [[ -v rules["$rule_key"] ]]; then
                     allowed_symbols_for_neighbor_set+=" ${rules[$rule_key]}"
                 fi
             done

             allowed_symbols_for_neighbor_set=$(echo "$allowed_symbols_for_neighbor_set" | tr ' ' '\n' | sort -u | tr '\n' ' ')
             allowed_symbols_for_neighbor_set="${allowed_symbols_for_neighbor_set% }"
             allowed_symbols_for_neighbor_set="${allowed_symbols_for_neighbor_set# }"

            local neighbor_current_options="${possibilities[$nkey]}"
            local neighbor_new_options=$(filter_options "$neighbor_current_options" "$allowed_symbols_for_neighbor_set")

            if [[ "$neighbor_current_options" != "$neighbor_new_options" ]]; then
                 possibilities[$nkey]="$neighbor_new_options"
                 # Keep grid value as possibilities string for renderer entropy display initially
                 grid[$nkey]="$neighbor_new_options"

                 if [[ -z "$neighbor_new_options" ]]; then
                     grid[$nkey]="$ERROR_SYMBOL" # Display error symbol
                     possibilities[$nkey]="" # Clear possibilities
                     collapsed[$nkey]=1
                     echo "WARN (wfc-basic-T): Contradiction at $nkey" >> "$LOG_FILE"
                 elif [[ ! -v processed_in_wave["$nkey"] ]]; then
                     # Process neighbors in LIFO (stack) order instead of FIFO (queue)
                     # This often helps focus propagation on more constrained areas first.
                     queue=("$nkey" "${queue[@]}"); processed_in_wave["$nkey"]=1
                 fi
            fi
        done # directions
    done # queue
}


# Initialize the grid state (General WFC logic)
init_grid() {
    grid=() possibilities=() collapsed=() # Clear global arrays
    local all_symbols="${SYMBOLS[*]}"
    echo "INFO (wfc-basic-T): Initializing grid (${ROWS}x${COLS}) with T symbols." >> "$LOG_FILE"
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            possibilities[$key]="$all_symbols"
            grid[$key]="$all_symbols" # Store possibilities initially for rendering
            collapsed[$key]=0
        done
    done
     echo "INFO (wfc-basic-T): Grid initialized." >> "$LOG_FILE"

    # --- Seed a corner to encourage box formation ---
    local seed_y=5
    local seed_x=5
    local seed_key="$seed_y,$seed_x"
    local seed_symbol="┌"
    if (( seed_y >= 0 && seed_y < ROWS && seed_x >= 0 && seed_x < COLS )); then
       log_event "INFO (wfc-basic-T): Seeding grid at $seed_key with '$seed_symbol'."
       possibilities[$seed_key]="$seed_symbol"
       grid[$seed_key]="$seed_symbol"
       collapsed[$seed_key]=1
       propagate "$seed_y" "$seed_x"
       log_event "INFO (wfc-basic-T): Propagation complete after seeding."
    else
       log_warn "WARN (wfc-basic-T): Seed coordinates ($seed_key) out of bounds (${ROWS}x${COLS}). Skipping seed."
    fi
}

# Core WFC update step (General WFC logic)
update_algorithm() {
    # Find cell with lowest entropy (>0)
    local min_entropy=9999 candidates=() all_collapsed=1 potential_contradiction=0
    for key in "${!possibilities[@]}"; do
        if [[ "${collapsed[$key]}" == "0" ]]; then
            all_collapsed=0
            local opts_str="${possibilities[$key]}"
            if [[ -z "$opts_str" ]]; then
                potential_contradiction=1;
                if [[ "${grid[$key]}" != "$ERROR_SYMBOL" ]]; then grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1; fi;
                continue
            fi
            local opts=($opts_str) entropy=${#opts[@]}
            if (( entropy > 0 )); then
                if (( entropy < min_entropy )); then
                    min_entropy=$entropy; candidates=("$key")
                elif (( entropy == min_entropy )); then candidates+=("$key"); fi
            elif (( entropy == 0 )); then # Should be caught by -z
                 potential_contradiction=1;
                 if [[ "${grid[$key]}" != "$ERROR_SYMBOL" ]]; then grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1; fi
            fi
        fi
    done

    if [[ $all_collapsed -eq 1 ]]; then
        STATUS_MESSAGE="WFC (T-Junctions) Complete!"; return 1
    fi
    if (( ${#candidates[@]} == 0 )); then
         if [[ $potential_contradiction -eq 1 ]]; then STATUS_MESSAGE="WFC (T-Junctions) Error: Contradiction"
         else STATUS_MESSAGE="WFC (T-Junctions) Error: No candidates"; fi
         return 1
    fi

    # Collapse a random candidate
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options=(${possibilities[$pick]})
    if (( ${#options[@]} == 0 )); then # Safety check
        STATUS_MESSAGE="WFC (T-Junctions) Error: Candidate $pick empty"; grid[$pick]="$ERROR_SYMBOL"; collapsed[$pick]=1; return 1
    fi
    local symbol="${options[$((RANDOM % ${#options[@]}))]}"

    grid[$pick]="$symbol" # Store final chosen symbol in grid
    collapsed[$pick]=1
    possibilities[$pick]="$symbol" # Reduce possibilities

    # Propagate constraints
    propagate "$y" "$x"

    local collapsed_count=0; for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    # Format the options string nicely for the status message
    local options_str="${options[*]}"
    STATUS_MESSAGE="WFC: $pick [$options_str] -> '$symbol' | $collapsed_count/$((ROWS*COLS))"
    return 0 # Success
}

# Function required by the rendering engine to get the current grid state
get_state() {
    local state_output=""
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            # Output the current value of the grid cell.
            # This will be a single collapsed character, the error symbol,
            # or potentially the string of possibilities if using entropy rendering later.
            state_output+="${grid[$key]:-"?"} " # Add cell value and a space delimiter
        done
        state_output+="\n" # Add newline after each row
    done
    printf "%s" "$state_output" # Use printf to avoid extra newline at the end
}
