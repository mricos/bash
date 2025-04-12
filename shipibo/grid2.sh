#!/usr/bin/env bash

# --- WFC Algorithm: Evolving 2x2 Braille Seed ---
# Starts with a fixed 2x2 pattern in the center and evolves outwards
# using Braille pattern compatibility rules.

# Define the specific symbols for the initial seed pattern (using a consistent one)
SEED_TL="⣿" SEED_TR="⣿"
SEED_BL="⣿" SEED_BR="⣿"

# Full set of symbols for the algorithm to use (including seed symbols)
# Make sure the seed symbols are included here if not already.
# Using the same set as wfc-basic.sh for consistency:
# ⠀(00) ⠉(09) ⠤(24) ⣀(06) ⡇(87) ⢸(E0) ⠿(3F) ⣶(E3) ⣤(6C) ⣿(FF)
# Seed symbol ⣿ (FF) is already included.
export SYMBOLS=("⠀" "⠉" "⠤" "⣀" "⡇" "⢸" "⠿" "⣶" "⣤" "⣿")
ERROR_SYMBOL="?"

# Export documentation pages
export PAGES=(
    "EVOLVING 2x2 BRAILLE SEED

Starts with a 2x2 Braille block
(⣿⣿ / ⣿⣿) in the center.

Then evolves outwards using WFC
with Braille compatibility rules."
    "HOW IT WORKS

1. init_grid places the 2x2 seed.
2. propagate updates neighbors.
3. update_algorithm finds the cell
   with Minimum Entropy (fewest
   valid options) and collapses it.
4. Repeats step 3, growing from
   the initial seed based on rules."
    "BRAILLE RULES

Neighboring Braille patterns must
have matching dots along their
shared edge to be valid.

This ensures visual continuity
as the pattern evolves."
    "SYMBOLS USED

Seed: ⣿⣿ / ⣿⣿
Full Set: ${SYMBOLS[*]}"
)


# --- Braille Helper Functions & Rule Generation (Copied from wfc-basic.sh) ---

# Associative array to map Braille char to its 8-bit pattern
declare -gA BRAILLE_PATTERNS
BRAILLE_PATTERNS=(
    ["⠀"]=0x00 ["⠉"]=0x09 ["⠤"]=0x24 ["⣀"]=0x06 ["⡇"]=0x87
    ["⢸"]=0xE0 ["⠿"]=0x3F ["⣶"]=0xE3 ["⣤"]=0x6C ["⣿"]=0xFF
    # Note: Seed patterns (now ⣿) are already in the base set
)
# Precompute dot presence for edge checking
declare -gA BRAILLE_DOTS
_init_braille_dots() {
    local char bits pat i dot_val
    BRAILLE_DOTS=() # Clear if re-sourcing
    for char in "${!BRAILLE_PATTERNS[@]}"; do
        bits=${BRAILLE_PATTERNS[$char]}
        pat=""
        for (( i=0; i<8; i++ )); do
            dot_val=$((1 << i))
            if (( (bits & dot_val) > 0 )); then pat="1${pat}"; else pat="0${pat}"; fi
        done
        BRAILLE_DOTS["$char"]="$pat"
    done
}
_init_braille_dots # Call helper to initialize

# Check Braille edge compatibility
check_braille_compatibility() {
    local char1="$1" char2="$2" dir="$3"
    local pat1="${BRAILLE_DOTS[$char1]}" pat2="${BRAILLE_DOTS[$char2]}"
    local compatible=1
    if [[ -z "$pat1" || -z "$pat2" ]]; then return 1; fi
    case "$dir" in
        right) [[ "${pat1:3:1}" == "${pat2:0:1}" ]] || compatible=0; [[ "${pat1:4:1}" == "${pat2:1:1}" ]] || compatible=0; [[ "${pat1:5:1}" == "${pat2:2:1}" ]] || compatible=0; [[ "${pat1:7:1}" == "${pat2:6:1}" ]] || compatible=0 ;;
        left)  [[ "${pat1:0:1}" == "${pat2:3:1}" ]] || compatible=0; [[ "${pat1:1:1}" == "${pat2:4:1}" ]] || compatible=0; [[ "${pat1:2:1}" == "${pat2:5:1}" ]] || compatible=0; [[ "${pat1:6:1}" == "${pat2:7:1}" ]] || compatible=0 ;;
        down)  [[ "${pat1:2:1}" == "${pat2:0:1}" ]] || compatible=0; [[ "${pat1:5:1}" == "${pat2:1:1}" ]] || compatible=0; [[ "${pat1:6:1}" == "${pat2:3:1}" ]] || compatible=0; [[ "${pat1:7:1}" == "${pat2:4:1}" ]] || compatible=0 ;;
        up)    [[ "${pat1:0:1}" == "${pat2:2:1}" ]] || compatible=0; [[ "${pat1:1:1}" == "${pat2:5:1}" ]] || compatible=0; [[ "${pat1:3:1}" == "${pat2:6:1}" ]] || compatible=0; [[ "${pat1:4:1}" == "${pat2:7:1}" ]] || compatible=0 ;;
        *) return 1 ;;
    esac
    if (( compatible == 1 )); then return 0; else return 1; fi
}

# Initialize the rules based on Braille compatibility
init_rules() {
    rules=() # Clear global rules
    echo "INFO (grid2.sh-evolve): Initializing Braille rules..." >> "$DEBUG_LOG_FILE"
    local sym1 sym2 dir allowed_for_sym1
    _init_braille_dots # Ensure maps are populated
    for sym1 in "${SYMBOLS[@]}"; do
        for dir in left right up down; do
            allowed_for_sym1=""
            for sym2 in "${SYMBOLS[@]}"; do
                if check_braille_compatibility "$sym1" "$sym2" "$dir"; then
                    allowed_for_sym1+="$sym2 "
                fi
            done
            rules["${sym1}_${dir}"]="${allowed_for_sym1% }"
        done
    done
    echo "INFO (grid2.sh-evolve): Rules initialized." >> "$DEBUG_LOG_FILE"
}

# --- Propagation Logic (Copied from wfc-basic.sh) ---

filter_options() {
    local current_options_str="$1" allowed_options_str="$2" result=""
    local -a current_options=($current_options_str)
    for opt in "${current_options[@]}"; do
        if [[ " $allowed_options_str " == *" $opt "* ]]; then result+="$opt "; fi
    done
    echo "${result% }"
}

propagate() {
    local y_start="$1" x_start="$2" # Coordinates that triggered propagation
    local -a queue=("$y_start,$x_start") # Start queue with the trigger cell
    local -A processed_in_wave
    processed_in_wave["$y_start,$x_start"]=1

    while (( ${#queue[@]} > 0 )); do
        local current_key="${queue[0]}"; queue=("${queue[@]:1}")
        local cy="${current_key%,*}" cx="${current_key#*,}"
        if [[ "${grid[$current_key]}" == "$ERROR_SYMBOL" ]]; then continue; fi # Don't propagate from error state

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

            # Check bounds and if neighbor is already collapsed
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )) || \
               [[ "${collapsed[$nkey]}" == "1" ]]; then continue; fi

            # Calculate allowed symbols for the neighbor based on ALL possibilities of the current cell
            local allowed_symbols_for_neighbor=""
            local -a current_cell_options=(${possibilities[$current_key]})
            if (( ${#current_cell_options[@]} == 0 )); then continue; fi # Skip if current cell has no options

            for current_opt in "${current_cell_options[@]}"; do
                 local rule_key="${current_opt}_${dir}"
                 if [[ -v rules["$rule_key"] ]]; then allowed_symbols_for_neighbor+=" ${rules[$rule_key]}"; fi
            done
            allowed_symbols_for_neighbor=$(echo "$allowed_symbols_for_neighbor" | tr ' ' '\n' | sort -u | tr '\n' ' ')
            allowed_symbols_for_neighbor="${allowed_symbols_for_neighbor% }"
            allowed_symbols_for_neighbor="${allowed_symbols_for_neighbor# }"

            if [[ -z "$allowed_symbols_for_neighbor" ]]; then continue; fi

            # Filter neighbor's options
            local neighbor_current_options="${possibilities[$nkey]}"
            local neighbor_new_options=$(filter_options "$neighbor_current_options" "$allowed_symbols_for_neighbor")

            # If options changed, update and enqueue neighbor
            if [[ "$neighbor_current_options" != "$neighbor_new_options" ]]; then
                 possibilities[$nkey]="$neighbor_new_options"
                 grid[$nkey]="$neighbor_new_options" # Keep grid entry as possibilities for render

                 if [[ -z "$neighbor_new_options" ]]; then
                     grid[$nkey]="$ERROR_SYMBOL"; possibilities[$nkey]=""; collapsed[$nkey]=1
                     echo "WARN (grid2.sh-propagate): Contradiction at $nkey" >> "$DEBUG_LOG_FILE"
                 elif [[ ! -v processed_in_wave["$nkey"] ]]; then
                     queue+=("$nkey"); processed_in_wave["$nkey"]=1
                 fi
            fi
        done # directions
    done # queue
}


# --- Engine-Called Functions ---

# Initialize the grid with the 2x2 seed in the center
init_grid() {
    grid=() possibilities=() collapsed=() # Clear globals
    local all_symbols="${SYMBOLS[*]}"
    echo "INFO (grid2.sh-evolve): Initializing grid (${ROWS}x${COLS}) for central 2x2 seed." >> "$DEBUG_LOG_FILE"

    # 1. Initialize all cells with full possibilities
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            possibilities[$key]="$all_symbols"
            grid[$key]="$all_symbols" # Set grid to possibilities for renderer
            collapsed[$key]=0
        done
    done

    # 2. Calculate center and define seed coordinates
    local cy=$(( (ROWS - 1) / 2 )) # Center Y (adjust for 0-based index)
    local cx=$(( (COLS - 1) / 2 )) # Center X (adjust for 0-based index)
    local key_tl="$cy,$cx"
    local key_tr="$cy,$((cx+1))"
    local key_bl="$((cy+1)),$cx"
    local key_br="$((cy+1)),$((cx+1))"
    local seed_keys=("$key_tl" "$key_tr" "$key_bl" "$key_br")
    # Use the SEED variables defined at the top
    local seed_symbols=("$SEED_TL" "$SEED_TR" "$SEED_BL" "$SEED_BR")

    echo "INFO (grid2.sh-evolve): Placing seed at ($cy,$cx) area." >> "$DEBUG_LOG_FILE"

    # 3. Set the seed pattern and mark as collapsed
    local i=0
    for key in "${seed_keys[@]}"; do
        local y_k="${key%,*}" x_k="${key#*,}"
        # Ensure coordinates are within bounds before setting
        if (( y_k >= 0 && y_k < ROWS && x_k >= 0 && x_k < COLS )); then
            grid[$key]="${seed_symbols[$i]}"
            possibilities[$key]="${seed_symbols[$i]}"
            collapsed[$key]=1
        fi
        ((i++))
    done

    # 4. Propagate from each seed cell
    for key in "${seed_keys[@]}"; do
         local y_k="${key%,*}" x_k="${key#*,}"
         if (( y_k >= 0 && y_k < ROWS && x_k >= 0 && x_k < COLS )) && [[ "${collapsed[$key]}" == 1 ]]; then
             propagate "$y_k" "$x_k"
         fi
    done

    STATUS_MESSAGE="Evolving 2x2 Grid Initialized"
    echo "INFO (grid2.sh-evolve): Grid initialized and seeded." >> "$DEBUG_LOG_FILE"
}

# Core WFC update step (Copied from wfc-basic.sh)
update_algorithm() {
    # Find cell with lowest entropy (>0)
    local min_entropy=9999 candidates=() all_collapsed=1 potential_contradiction=0
    for key in "${!possibilities[@]}"; do
        if [[ "${collapsed[$key]}" == "0" ]]; then
            all_collapsed=0
            local opts_str="${possibilities[$key]}"
            if [[ -z "$opts_str" ]]; then
                potential_contradiction=1; grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1; continue
            fi
            local opts=($opts_str) entropy=${#opts[@]}
            if (( entropy > 0 )); then
                if (( entropy < min_entropy )); then
                    min_entropy=$entropy; candidates=("$key")
                elif (( entropy == min_entropy )); then candidates+=("$key"); fi
            elif (( entropy == 0 )); then # Should be caught by -z
                 potential_contradiction=1; grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1
            fi
        fi
    done

    if [[ $all_collapsed -eq 1 ]]; then
        STATUS_MESSAGE="Evolving 2x2 Grid Complete!"; return 1
    fi
    if (( ${#candidates[@]} == 0 )); then
         if [[ $potential_contradiction -eq 1 ]]; then STATUS_MESSAGE="Evolving 2x2 Grid Error: Contradiction"
         else STATUS_MESSAGE="Evolving 2x2 Grid Error: No candidates"; fi
         return 1
    fi

    # Collapse a random candidate
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options=(${possibilities[$pick]})
    if (( ${#options[@]} == 0 )); then # Safety check
        STATUS_MESSAGE="Evolving 2x2 Grid Error: Candidate $pick empty"; grid[$pick]="$ERROR_SYMBOL"; collapsed[$pick]=1; return 1
    fi
    local symbol="${options[$((RANDOM % ${#options[@]}))]}"

    grid[$pick]="$symbol"
    collapsed[$pick]=1
    possibilities[$pick]="$symbol" # Reduce possibilities

    # Propagate constraints
    propagate "$y" "$x"

    local collapsed_count=0; for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    STATUS_MESSAGE="Evolving 2x2 Grid: Collapsed $pick ('$symbol') | $collapsed_count/$((ROWS*COLS))"
    return 0 # Success
}
