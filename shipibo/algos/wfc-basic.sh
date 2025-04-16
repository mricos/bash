#!/usr/bin/env bash

# --- WFC Algorithm: Simple T-Junctions ---

# Define the new symbol set
export SYMBOLS=("·" "─" "├" "┬" "┤")
ERROR_SYMBOL=" " # Use space for contradictions

# Export documentation pages
export PAGES=(
    "WFC: Simple T-Junctions

Generates patterns using a small
set of line and T-junction symbols:
· ─ ├ ┬ ┤
Uses Wave Function Collapse with
Minimum Entropy and connection rules."
    "RULES

- · (Dot): Represents empty space,
  connects freely.
- ─ (H Line): Connects Left/Right
  to ─, ├, ┤. Up/Down to ┬, ·.
- ├ (T Right): Connects Left to ─.
  Right to ─, ┤. Up/Down to ·, ┬.
- ┬ (T Down): Connects Left/Right
  to ─, ├, ┤. Up to ·. Down to ·.
- ┤ (T Left): Connects Right to ─.
  Left to ─, ├. Up/Down to ·, ┬."

    "ALGORITHM STEPS

1. Observe: Find uncollapsed cell
   with lowest entropy (>0).
2. Collapse: Choose random valid symbol.
3. Propagate: Update neighbor options.
4. Repeat until grid full or error.
Contradictions are shown as space."
    "SYMBOLS USED

Set: ${SYMBOLS[*]}
Error: Shown as Space"
)

# Initialize connection rules for T-junctions
init_rules() {
    rules=() # Clear global rules
    echo "INFO (wfc-basic-T): Initializing T-junction rules..." >> "$LOG_FILE"

    # Define connections: what can be placed TO THE [dir] OF the key symbol
    # · (Dot/Empty) - Connects freely to anything
    rules["·_left"]="· ─ ├ ┬ ┤"
    rules["·_right"]="· ─ ├ ┬ ┤"
    rules["·_up"]="· ─ ├ ┬ ┤"
    rules["·_down"]="· ─ ├ ┬ ┤"

    # ─ (Horizontal Line)
    rules["─_left"]="─ ├ ·"     # Needs connection from Right: ─, ├, ·(space)
    rules["─_right"]="─ ┤ ·"    # Needs connection from Left:  ─, ┤, ·(space)
    rules["─_up"]="┬ ·"         # Needs connection from Bottom: ┬, ·(space)
    rules["─_down"]="·"         # Needs connection from Top: ·(space) only (no T-up symbol)

    # ├ (Tee Right) - Connects L, U, D
    rules["├_left"]="─ ┤ ·"     # Needs connection from Left:  ─, ┤, ·(space)
    rules["├_right"]="·"        # Needs connection from Right: ·(space) only
    rules["├_up"]="┬ ·"         # Needs connection from Bottom: ┬, ·(space)
    rules["├_down"]="·"         # Needs connection from Top: ·(space) only

    # ┬ (Tee Down) - Connects L, R, U
    rules["┬_left"]="─ ├ ·"     # Needs connection from Right: ─, ├, ·(space)
    rules["┬_right"]="─ ┤ ·"    # Needs connection from Left:  ─, ┤, ·(space)
    rules["┬_up"]="┬ ·"         # Needs connection from Bottom: ┬, ·(space)
    rules["┬_down"]="·"         # Needs connection from Top: Allow space.

    # ┤ (Tee Left) - Connects R, U, D
    rules["┤_left"]="·"         # Needs connection from Right: ·(space) only
    rules["┤_right"]="─ ├ ·"    # Needs connection from Left:  ─, ├, ·(space)
    rules["┤_up"]="┬ ·"         # Needs connection from Bottom: ┬, ·(space)
    rules["┤_down"]="·"         # Needs connection from Top: ·(space) only

    # Ensure all defined symbols have entries for all directions
    local -a all_dirs=("left" "right" "up" "down")
    for sym in "${SYMBOLS[@]}"; do
        for dir in "${all_dirs[@]}"; do
            local rule_key="${sym}_${dir}"
            [[ -v rules["$rule_key"] ]] || rules["$rule_key"]=""
        done
    done
    echo "INFO (wfc-basic-T): T-junction rules initialized." >> "$LOG_FILE"
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

        local -a symbols_to_propagate_from=($current_possibility_list)

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
            for current_opt in "${symbols_to_propagate_from[@]}"; do
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
                     queue+=("$nkey"); processed_in_wave["$nkey"]=1
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
    STATUS_MESSAGE="WFC (T-Junctions): Collapsed $pick ('$symbol') | $collapsed_count/$((ROWS*COLS))"
    return 0 # Success
}
