#!/usr/bin/env bash

# --- WFC Algorithm: Blocky Colored Shapes ---
# Uses block elements (▀ ▄ ▌ ▐ █) and space with rules
# to create blocky patterns, incorporating two colors.

# Define the base symbols
export SYMBOLS=("▀" "▄" "▌" "▐" "█" " ") # Base symbols for rules/possibilities
ERROR_SYMBOL=" "

# Define the two colors (ANSI codes)
COLOR1=34 # Blue
COLOR2=36 # Cyan

# Export documentation pages
export PAGES=(
    "BLOCKY COLORED SHAPES

Uses block characters (▀ ▄ ▌ ▐ █)
and space with WFC rules to
generate evolving blocky patterns.
Uses two colors randomly.
Contradictions appear as spaces."
    "HOW IT WORKS

1. Rules define how block elements
   connect (e.g., ▀ needs █ or ▀ below).
2. WFC collapses cells using the
   Minimum Entropy heuristic.
3. Color is chosen randomly upon collapse.
4. The grid stores the colored char."
    "RULES

- █ connects freely.
- ▀ connects down to █/▀, sideways.
- ▄ connects up to █/▄, sideways.
- ▌ connects right to █/▌, vertically.
- ▐ connects left to █/▐, vertically.
- Space connects freely."
    "SYMBOLS & COLORS

Symbols: ${SYMBOLS[*]}
Colors: Blue ($COLOR1), Cyan ($COLOR2)
Errors: Shown as Space"
)

# --- Rule Definition ---

# Define connection rules for block symbols
init_rules() {
    rules=() # Clear global rules
    echo "INFO (blocky.sh): Initializing block rules..." >> "$DEBUG_LOG_FILE"

    # Define connections for each symbol [Symbol_Direction]="Allowed Symbols"
    # █ (Full Block) - Connects freely to blocky things or space
    rules["█_left"]="█ ▀ ▄ ▌ ▐  "
    rules["█_right"]="█ ▀ ▄ ▌ ▐  "
    rules["█_up"]="█ ▀ ▄ ▌ ▐  "
    rules["█_down"]="█ ▀ ▄ ▌ ▐  "

    # ▀ (Upper Half Block)
    rules["▀_left"]="█ ▀ ▌ ▐  " # Can connect left/right to full, upper, or vertical halves
    rules["▀_right"]="█ ▀ ▌ ▐  "
    rules["▀_up"]=" "           # Connects up only to space
    rules["▀_down"]="█ ▀  "     # Connects down to full or another upper

    # ▄ (Lower Half Block)
    rules["▄_left"]="█ ▄ ▌ ▐  " # Can connect left/right to full, lower, or vertical halves
    rules["▄_right"]="█ ▄ ▌ ▐  "
    rules["▄_up"]="█ ▄  "       # Connects up to full or another lower
    rules["▄_down"]=" "         # Connects down only to space

    # ▌ (Left Half Block)
    rules["▌_left"]=" "         # Connects left only to space
    rules["▌_right"]="█ ▌  "    # Connects right to full or another left half
    rules["▌_up"]="█ ▌ ▀ ▄  "   # Connects up/down to full, self, or horizontal halves
    rules["▌_down"]="█ ▌ ▀ ▄  "

    # ▐ (Right Half Block)
    rules["▐_left"]="█ ▐  "     # Connects left to full or another right half
    rules["▐_right"]=" "        # Connects right only to space
    rules["▐_up"]="█ ▐ ▀ ▄  "   # Connects up/down to full, self, or horizontal halves
    rules["▐_down"]="█ ▐ ▀ ▄  "

    #   (Space) - Connects freely
    rules[" _left"]="█ ▀ ▄ ▌ ▐  "
    rules[" _right"]="█ ▀ ▄ ▌ ▐  "
    rules[" _up"]="█ ▀ ▄ ▌ ▐  "
    rules[" _down"]="█ ▀ ▄ ▌ ▐  "

    # Ensure all defined symbols have entries for all directions (even if empty)
    local -a all_dirs=("left" "right" "up" "down")
    for sym in "${SYMBOLS[@]}"; do
        for dir in "${all_dirs[@]}"; do
            local rule_key="${sym}_${dir}"
            # If a rule isn't explicitly defined above, assume it's empty
            [[ -v rules["$rule_key"] ]] || rules["$rule_key"]=""
        done
    done

    echo "INFO (blocky.sh): Block rules initialized." >> "$DEBUG_LOG_FILE"
}


# --- WFC Logic (Adapted from Braille version) ---

filter_options() {
    local current_options_str="$1" allowed_options_str="$2" result=""
    local -a current_options=($current_options_str)
    for opt in "${current_options[@]}"; do
        # Check base symbol compatibility
        if [[ " $allowed_options_str " == *" $opt "* ]]; then result+="$opt "; fi
    done
    echo "${result% }"
}

propagate() {
    local y_start="$1" x_start="$2" # Coordinates that triggered propagation
    local collapsed_base_symbol="${possibilities[$y_start,$x_start]}" # Get the base symbol

    local -a queue=("$y_start,$x_start") # Start queue with the trigger cell
    local -A processed_in_wave
    processed_in_wave["$y_start,$x_start"]=1

    while (( ${#queue[@]} > 0 )); do
        local current_key="${queue[0]}"; queue=("${queue[@]:1}")
        local cy="${current_key%,*}" cx="${current_key#*,}"
        # Use possibilities array for rule checking (contains base symbols)
        local current_base_symbol="${possibilities[$current_key]}"
        # Check if current cell possibilities became empty (contradiction from previous step)
        if [[ -z "$current_base_symbol" ]]; then continue; fi

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

            # Calculate allowed symbols for the neighbor based on the *single* known symbol of the current cell
            local allowed_symbols_for_neighbor=""
            local rule_key="${current_base_symbol}_${dir}"
            if [[ -v rules["$rule_key"] ]]; then
                 allowed_symbols_for_neighbor="${rules[$rule_key]}"
            fi
            # No need to merge possibilities here since current cell is collapsed to one base symbol

            # Filter neighbor's options
            local neighbor_current_options="${possibilities[$nkey]}"
            local neighbor_new_options=$(filter_options "$neighbor_current_options" "$allowed_symbols_for_neighbor")

            # If options changed, update and enqueue neighbor
            if [[ "$neighbor_current_options" != "$neighbor_new_options" ]]; then
                 possibilities[$nkey]="$neighbor_new_options"
                 # DO NOT update grid[$nkey] here - it holds colored chars or placeholders

                 if [[ -z "$neighbor_new_options" ]]; then
                     # Contradiction: Set grid to space, clear possibilities, mark collapsed
                     grid[$nkey]="$ERROR_SYMBOL"; possibilities[$nkey]=""; collapsed[$nkey]=1 # Already uses ERROR_SYMBOL
                     echo "WARN (blocky.sh-propagate): Contradiction at $nkey, setting to space." >> "$DEBUG_LOG_FILE"
                 elif [[ ! -v processed_in_wave["$nkey"] ]]; then
                     # Neighbor possibilities reduced, add to queue IF IT HASN'T ALREADY BEEN
                     # This requires propagating from the neighbor using its reduced possibilities
                     # For simplicity here, we just enqueue it - might lead to redundant checks
                     # A more refined approach would check if the possibilities derived *from this neighbor*
                     # have changed compared to previously.
                     queue+=("$nkey"); processed_in_wave["$nkey"]=1
                 fi
            fi
        done # directions
    done # queue
}


# --- Engine-Called Functions ---

# Initialize the grid state
init_grid() {
    grid=() possibilities=() collapsed=() # Clear globals
    local all_symbols="${SYMBOLS[*]}"
    echo "INFO (blocky.sh): Initializing grid (${ROWS}x${COLS}) for blocky shapes." >> "$DEBUG_LOG_FILE"

    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            possibilities[$key]="$all_symbols" # Store base symbols
            grid[$key]="" # Grid stores final colored char or placeholder
            collapsed[$key]=0
        done
    done

    # Optional: Seed the grid (e.g., center)
    # local seed_y=$((ROWS / 2)) seed_x=$((COLS / 2)) key="$seed_y,$seed_x"
    # local base_symbol="█" color_code="$COLOR1"
    # grid[$key]="$(printf '\033[%sm%s\033[0m' "$color_code" "$base_symbol")"
    # possibilities[$key]="$base_symbol"
    # collapsed[$key]=1
    # propagate "$seed_y" "$seed_x"

    STATUS_MESSAGE="Blocky Shapes Initialized"
    echo "INFO (blocky.sh): Grid initialized." >> "$DEBUG_LOG_FILE"
}

# Helper to extract ANSI color code (digits) from a grid value string
get_color_from_grid_value() {
    local grid_val="$1"
    # Regex to find \e[<digits>m at the start
    if [[ "$grid_val" =~ ^$'\x1B'\['([0-9]+)'m ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "" # Return empty if no color code found
    fi
}

# Core WFC update step
update_algorithm() {
    # Find cell with lowest entropy (>0) based on possibilities
    local min_entropy=9999 candidates=() all_collapsed=1 potential_contradiction=0
    for key in "${!possibilities[@]}"; do
        if [[ "${collapsed[$key]}" == "0" ]]; then
            all_collapsed=0
            local opts_str="${possibilities[$key]}"
            if [[ -z "$opts_str" ]]; then
                potential_contradiction=1; if [[ "${grid[$key]}" != "$ERROR_SYMBOL" ]]; then grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1; fi; continue
            fi
            local opts=($opts_str) entropy=${#opts[@]}
            if (( entropy > 0 )); then
                if (( entropy < min_entropy )); then
                    min_entropy=$entropy; candidates=("$key")
                elif (( entropy == min_entropy )); then candidates+=("$key"); fi
            elif (( entropy == 0 )); then # Should be caught by -z
                 potential_contradiction=1; if [[ "${grid[$key]}" != "$ERROR_SYMBOL" ]]; then grid[$key]="$ERROR_SYMBOL"; collapsed[$key]=1; fi
            fi
        fi
    done

    if [[ $all_collapsed -eq 1 ]]; then STATUS_MESSAGE="Blocky Shapes Complete!"; return 1; fi
    if (( ${#candidates[@]} == 0 )); then
         if [[ $potential_contradiction -eq 1 ]]; then STATUS_MESSAGE="Blocky Shapes Error: Contradiction"
         else STATUS_MESSAGE="Blocky Shapes Error: No candidates"; fi
         return 1
    fi

    # Collapse a random candidate
    local pick="${candidates[$((RANDOM % ${#candidates[@]}))]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options=(${possibilities[$pick]}) # Base symbol options
    if (( ${#options[@]} == 0 )); then # Safety check
        STATUS_MESSAGE="Blocky Shapes Error: Candidate $pick empty"; grid[$pick]="$ERROR_SYMBOL"; collapsed[$pick]=1; return 1
    fi
    local base_symbol="${options[$((RANDOM % ${#options[@]}))]}" # Choose base symbol

    # --- Determine Preferred Color based on Neighbors ---
    local color_code # The final color code to use
    if [[ "$base_symbol" == " " ]]; then
        # Don't assign color logic to spaces
        color_code="" # Will result in final_symbol being just " "
    else
        local color1_neighbors=0
        local color2_neighbors=0
        local -a directions=("left" "right" "up" "down")
        for dir in "${directions[@]}"; do
            local ny nx
            case "$dir" in
                left)  ny="$y"; nx=$((x - 1)); ;;
                right) ny="$y"; nx=$((x + 1)); ;;
                up)    ny=$((y - 1)); nx="$x"; ;;
                down)  ny=$((y + 1)); nx="$x"; ;;
            esac
            local nkey="$ny,$nx"

            # Check bounds and if neighbor is collapsed
            if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && \
               [[ "${collapsed[$nkey]}" == "1" ]]; then
                local neighbor_grid_value="${grid[$nkey]}"
                local neighbor_color=$(get_color_from_grid_value "$neighbor_grid_value")
                if [[ "$neighbor_color" == "$COLOR1" ]]; then
                    ((color1_neighbors++))
                elif [[ "$neighbor_color" == "$COLOR2" ]]; then
                    ((color2_neighbors++))
                fi
            fi
        done

        # Choose dominant color or random if tied/no neighbors
        if (( color1_neighbors > color2_neighbors )); then
            color_code=$COLOR1
        elif (( color2_neighbors > color1_neighbors )); then
            color_code=$COLOR2
        else
            # Tie or no colored neighbors, choose randomly
            color_code=$(( RANDOM % 2 == 0 ? COLOR1 : COLOR2 ))
        fi
    fi
    # --- End Color Determination ---

    # Construct final colored string for the grid array
    local final_symbol
    if [[ -z "$color_code" ]]; then # Handles the space case
        final_symbol=" "
    else
        final_symbol=$(printf '\033[%sm%s\033[0m' "$color_code" "$base_symbol")
    fi

    # Update global state
    grid[$pick]="$final_symbol"        # Store colored char in grid
    possibilities[$pick]="$base_symbol" # Store base char in possibilities
    collapsed[$pick]=1

    # Propagate constraints using the base symbol
    propagate "$y" "$x"

    local collapsed_count=0; for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    STATUS_MESSAGE="Blocky: Collapsed $pick ('$base_symbol') | $collapsed_count/$((ROWS*COLS))"
    return 0 # Success
}
