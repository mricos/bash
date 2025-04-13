#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8
# Or potentially just: export LC_ALL=C.UTF-8

# --- WFC Algorithm: Blocky ASCII Shapes ---
# Uses block characters with WFC rules
# to create evolving geometric patterns. Compatible with standard terminals.

# Define the base symbols
export SYMBOLS=("▀" "▄" "▌" "▐" "█" " ") # Block characters + Space
export ERROR_SYMBOL="X" # Use a distinct error symbol

# Define Tile size for the engine
export ALGO_TILE_WIDTH=1
export ALGO_TILE_HEIGHT=1

# Export documentation pages (Updated for block characters)
export PAGES=(
    "BLOCKY SHAPES

Uses block characters (▀ ▄ ▌ ▐ █)
and space with WFC rules to
generate evolving geometric patterns.
Contradictions appear as '$ERROR_SYMBOL'."
    "HOW IT WORKS

1. Rules define how block elements
   connect visually (adjacency).
2. WFC collapses cells using the
   Minimum Entropy heuristic.
3. The grid stores the chosen character
   with ANSI color codes."
    "RULES (Visual Adjacency)

- █ (full): Connects freely on all sides.
- ' ' (space): Connects freely (no constraints).
- ▀ (upper): Connects down/sides freely.
             Connects UP only to █, ▄, ' '.
- ▄ (lower): Connects up/sides freely.
             Connects DOWN only to █, ▀, ' '.
- ▌ (left): Connects right/vertical freely.
            Connects LEFT only to █, ▐, ' '.
- ▐ (right): Connects left/vertical freely.
             Connects RIGHT only to █, ▌, ' '."

    "SYMBOLS

█ - Full block
▀ - Upper half block
▄ - Lower half block
▌ - Left half block
▐ - Right half block
  - Space (Empty)"
)

# --- Rule Definition ---

# Define connection rules for block symbols based on visual adjacency
# Format: rules["SYMBOL_direction"]="ALLOWED_NEIGHBORS"
init_rules() {
    # Ensure rules is declared globally if not already by engine
    declare -gA rules
    rules=() # Clear previous rules
    echo "INFO (blocky.sh): Initializing block character rules..." >> "$DEBUG_LOG_FILE"

    local all_symbols="▀ ▄ ▌ ▐ █  " # All symbols including space

    # █ (Full Block) - Connects to everything
    rules["█_left"]="$all_symbols"
    rules["█_right"]="$all_symbols"
    rules["█_up"]="$all_symbols"
    rules["█_down"]="$all_symbols"

    # ' ' (Space) - Connects to everything (empty space doesn't constrain)
    rules[" _left"]="$all_symbols"
    rules[" _right"]="$all_symbols"
    rules[" _up"]="$all_symbols"
    rules[" _down"]="$all_symbols"

    # ▀ (Upper Half Block)
    rules["▀_left"]="$all_symbols"  # Side connection free
    rules["▀_right"]="$all_symbols" # Side connection free
    rules["▀_up"]="█ ▄  "         # Connects UP only to things with a bottom half
    rules["▀_down"]="$all_symbols"  # Connects DOWN freely

    # ▄ (Lower Half Block)
    rules["▄_left"]="$all_symbols"  # Side connection free
    rules["▄_right"]="$all_symbols" # Side connection free
    rules["▄_up"]="$all_symbols"  # Connects UP freely
    rules["▄_down"]="█ ▀  "         # Connects DOWN only to things with a top half

    # ▌ (Left Half Block)
    rules["▌_left"]="█ ▐  "         # Connects LEFT only to things with a right half
    rules["▌_right"]="$all_symbols" # Connects RIGHT freely
    rules["▌_up"]="$all_symbols"    # Vertical connection free
    rules["▌_down"]="$all_symbols"  # Vertical connection free

    # ▐ (Right Half Block)
    rules["▐_left"]="$all_symbols"  # Connects LEFT freely
    rules["▐_right"]="█ ▌  "        # Connects RIGHT only to things with a left half
    rules["▐_up"]="$all_symbols"    # Vertical connection free
    rules["▐_down"]="$all_symbols"  # Vertical connection free

    echo "INFO (blocky.sh): Block character rules initialized." >> "$DEBUG_LOG_FILE"
}

# --- WFC Logic Helper ---

# Filters a string of options against another string of allowed options
# Returns a space-separated string of valid options
filter_options() {
    local string1="$1"
    local string2="$2"
    local common_chars=""
    local char

    # If either string is empty, intersection is empty
    if [[ -z "$string1" || -z "$string2" ]]; then
        echo ""
        return
    fi

    # Iterate through chars of the first string
    for (( i=0; i<${#string1}; i++ )); do
        char="${string1:$i:1}"
        # Check if the char exists in the second string
        if [[ "$string2" == *"$char"* ]]; then
            # Add to result if not already there (optional, prevents duplicates in output)
             if [[ "$common_chars" != *"$char"* ]]; then
                common_chars+="$char"
             fi
        fi
    done

    # Return the common characters, sorted for consistency (optional but good practice)
    echo "$common_chars" | grep -o . | sort -u | tr -d '\n'
}


# --- WFC Propagation ---
propagate() {
    local y_start="$1" x_start="$2"
    local key_start="$y_start,$x_start"

    # Check if start cell is valid and collapsed
    if [[ -z "${possibilities[$key_start]}" || "${collapsed[$key_start]}" != "1" ]]; then
        echo "WARN (blocky.sh propagate): Start cell $key_start not valid or not collapsed. Poss: '${possibilities[$key_start]}', Coll: '${collapsed[$key_start]}'." >> "$DEBUG_LOG_FILE"
        return
    fi
    local collapsed_base_symbol="${possibilities[$key_start]}" # Should be a single symbol now

    local -a queue=("$key_start")
    local -A processed_in_wave # Keep track of cells processed in this specific wave to prevent cycles within one propagation burst
    processed_in_wave["$key_start"]=1

    echo "DEBUG (blocky.sh propagate): Starting propagation from $key_start with symbol '$collapsed_base_symbol'" >> "$DEBUG_LOG_FILE"

    while (( ${#queue[@]} > 0 )); do
        local current_key="${queue[0]}"; queue=("${queue[@]:1}")
        local cy="${current_key%,*}" cx="${current_key#*,}"
        local current_possibilities="${possibilities[$current_key]}"

        echo "DEBUG (blocky.sh propagate): Processing $current_key | possibilities: '$current_possibilities'" >> "$DEBUG_LOG_FILE"

        if [[ -z "$current_possibilities" || "$current_possibilities" == "$ERROR_SYMBOL" ]]; then
             echo "DEBUG (blocky.sh propagate): Skipping $current_key due to empty or error state." >> "$DEBUG_LOG_FILE"
             continue # Skip if cell is already in error state or somehow empty
        fi

        # Determine valid neighbors based on *all* current possibilities for the current cell
        # This allows propagation even before a cell is fully collapsed to one state
        local combined_allowed_symbols_for_neighbor_left=""
        local combined_allowed_symbols_for_neighbor_right=""
        local combined_allowed_symbols_for_neighbor_up=""
        local combined_allowed_symbols_for_neighbor_down=""

        # For each possible symbol in the current cell, find what it allows in each direction
        for (( i=0; i<${#current_possibilities}; i++ )); do
            local sym="${current_possibilities:$i:1}"
            combined_allowed_symbols_for_neighbor_left+="${rules[${sym}_left]-}"
            combined_allowed_symbols_for_neighbor_right+="${rules[${sym}_right]-}"
            combined_allowed_symbols_for_neighbor_up+="${rules[${sym}_up]-}"
            combined_allowed_symbols_for_neighbor_down+="${rules[${sym}_down]-}"
        done

        # Deduplicate the combined allowed symbols for each direction
        local allowed_left=$(echo "$combined_allowed_symbols_for_neighbor_left" | grep -o . | sort -u | tr -d '\n')
        local allowed_right=$(echo "$combined_allowed_symbols_for_neighbor_right" | grep -o . | sort -u | tr -d '\n')
        local allowed_up=$(echo "$combined_allowed_symbols_for_neighbor_up" | grep -o . | sort -u | tr -d '\n')
        local allowed_down=$(echo "$combined_allowed_symbols_for_neighbor_down" | grep -o . | sort -u | tr -d '\n')

        echo "DEBUG (blocky.sh propagate): Cell $current_key allows neighbors: L:'$allowed_left' R:'$allowed_right' U:'$allowed_up' D:'$allowed_down'" >> "$DEBUG_LOG_FILE"


        local -a directions=("left" "right" "up" "down")
        for dir in "${directions[@]}"; do
            local ny nx opposite_dir allowed_symbols_for_neighbor_from_perspective
            case "$dir" in
                left)  ny="$cy"; nx=$((cx - 1)); opposite_dir="right"; allowed_symbols_for_neighbor_from_perspective="$allowed_left" ;;
                right) ny="$cy"; nx=$((cx + 1)); opposite_dir="left";  allowed_symbols_for_neighbor_from_perspective="$allowed_right" ;;
                up)    ny=$((cy - 1)); nx="$cx"; opposite_dir="down";  allowed_symbols_for_neighbor_from_perspective="$allowed_up" ;;
                down)  ny=$((cy + 1)); nx="$cx"; opposite_dir="up";    allowed_symbols_for_neighbor_from_perspective="$allowed_down" ;;
            esac
            local nkey="$ny,$nx"

            # Boundary checks and check if neighbor is already collapsed
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )) || \
               [[ "${collapsed[$nkey]:-0}" == "1" ]]; then
                 # echo "DEBUG (blocky.sh propagate): Skipping neighbor $nkey (boundary or collapsed)." >> "$DEBUG_LOG_FILE"
                 continue
            fi

            local neighbor_current_options="${possibilities[$nkey]}"

            # Filter the neighbor's *current* options based on what the *current* cell allows for that direction
            local neighbor_new_options=$(filter_options "$neighbor_current_options" "$allowed_symbols_for_neighbor_from_perspective")

            # --- IMPORTANT: Constraint Backwards ---
            # Now, we must also consider the constraints imposed *by* the neighbor *onto* the current cell (using the opposite direction rules)
            # This is crucial for ensuring consistency. Re-filter the current cell's possibilities based on what the neighbor *could* be.
            # This step wasn't explicitly in the original logic but is standard WFC.

            # Let's simplify for now and stick to the forward propagation as in the original script structure,
            # but ensure the filtering logic is correct. The core issue was rule mismatch.


            if [[ "$neighbor_current_options" != "$neighbor_new_options" ]]; then
                echo "DEBUG (blocky.sh propagate): Updating neighbor $nkey. Old: '$neighbor_current_options', Allowed: '$allowed_symbols_for_neighbor_from_perspective', New: '$neighbor_new_options'" >> "$DEBUG_LOG_FILE"

                possibilities[$nkey]="$neighbor_new_options"

                if [[ -z "$neighbor_new_options" ]]; then
                    # Contradiction detected!
                    grid[$nkey]="$ERROR_SYMBOL"
                    possibilities[$nkey]="$ERROR_SYMBOL" # Mark possibilities as error state
                    collapsed[$nkey]=1 # Mark as collapsed (to error state)
                    cell_colors[$nkey]="" # No color for error
                    echo "WARN (blocky.sh propagate): Contradiction at $nkey propagating from $current_key. Setting to '$ERROR_SYMBOL'." >> "$DEBUG_LOG_FILE"
                    # Do not add to queue, contradiction stops propagation path here
                elif [[ ! -v processed_in_wave["$nkey"] ]]; then
                    # If possibilities changed and not yet processed in this wave, add to queue
                    queue+=("$nkey")
                    processed_in_wave["$nkey"]=1
                     echo "DEBUG (blocky.sh propagate): Adding $nkey to queue." >> "$DEBUG_LOG_FILE"
                fi
            # else
                 # echo "DEBUG (blocky.sh propagate): No change for neighbor $nkey ('$neighbor_current_options')." >> "$DEBUG_LOG_FILE"
            fi
        done
    done
     echo "DEBUG (blocky.sh propagate): Propagation finished for wave starting at $key_start." >> "$DEBUG_LOG_FILE"
}


# --- Color Management ---
declare -A cell_colors # Store color identifiers (e.g., "1", "2")

# Color Definitions (ANSI color codes)
COLOR1_FG="37"  # White foreground
COLOR1_BG="44"  # Blue background
COLOR2_FG="37"  # White foreground
COLOR2_BG="46"  # Cyan background

# Helper to apply ANSI colors
color_char() {
    local fg_color="$1"
    local bg_color="$2"
    local char="$3"
    echo -e "\033[${fg_color};${bg_color}m${char}\033[0m"
}

# --- Grid Initialization ---
init_grid() {
    # Ensure global scope for engine compatibility
    declare -gA grid possibilities collapsed cell_colors
    grid=() possibilities=() collapsed=() cell_colors=()

    local all_symbols_str=""
    for sym in "${SYMBOLS[@]}"; do all_symbols_str+="$sym"; done
    # Remove potential duplicates from SYMBOLS array if any
    all_symbols_str=$(echo "$all_symbols_str" | grep -o . | sort -u | tr -d '\n')


    echo "INFO (blocky.sh): Initializing grid (${ROWS}x${COLS}) for blocky shapes." >> "$DEBUG_LOG_FILE"
    echo "INFO (blocky.sh): Initial possibilities string: '$all_symbols_str'" >> "$DEBUG_LOG_FILE"


    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            possibilities[$key]="$all_symbols_str"
            grid[$key]=" " # Initialize grid with space
            collapsed[$key]=0
            cell_colors[$key]=""
        done
    done

    # Seed the grid with a colored block in the center
    local seed_y=$((ROWS / 2)) seed_x=$((COLS / 2))
    local key="$seed_y,$seed_x"
    local base_symbol="█" # Start with a full block

    if [[ "$all_symbols_str" == *"$base_symbol"* ]]; then
        possibilities[$key]="$base_symbol"
        collapsed[$key]=1
        cell_colors[$key]="1" # Use identifier '1' for COLOR1
        grid[$key]="$base_symbol"

        echo "INFO (blocky.sh): Seeding grid at $key with '$base_symbol' (Color 1)." >> "$DEBUG_LOG_FILE"
        propagate "$seed_y" "$seed_x"
    else
        echo "ERROR (blocky.sh): Seed symbol '$base_symbol' not found in initial possibilities '$all_symbols_str'. Cannot seed." >> "$DEBUG_LOG_FILE"
        STATUS_MESSAGE="Blocky Error: Invalid seed symbol"
        return 1
    fi


    STATUS_MESSAGE="Blocky Shapes Initialized"
    echo "INFO (blocky.sh): Grid initialized and seeded." >> "$DEBUG_LOG_FILE"
}

# --- Core WFC Update Step ---
update_algorithm() {
    local min_entropy=9999 candidates=() all_collapsed=1 potential_contradiction=0 lowest_entropy_key=""
    local entropy # Reuse variable

    echo "DEBUG (blocky.sh update): Searching for minimum entropy cell..." >> "$DEBUG_LOG_FILE"

    # Find cell(s) with the minimum number of possibilities (entropy)
    for key in "${!possibilities[@]}"; do
        if [[ "${collapsed[$key]:-0}" == "0" ]]; then
            all_collapsed=0 # Found at least one uncollapsed cell
            local opts_str="${possibilities[$key]-}"

            # Calculate entropy (number of possible symbols)
             entropy=${#opts_str}
             echo "TRACE (blocky.sh update): Cell $key | Options: '$opts_str' | Entropy: $entropy" >> "$DEBUG_LOG_FILE"


            if [[ -z "$opts_str" || "$opts_str" == "$ERROR_SYMBOL" ]]; then
                # This cell already reached a contradiction in a previous step
                # We mark it as collapsed to avoid re-processing, but log it.
                if [[ "${collapsed[$key]:-0}" == "0" ]]; then # Only update if not already marked collapsed
                    echo "WARN (blocky.sh update): Found pre-existing contradiction at $key during entropy scan. Marking collapsed." >> "$DEBUG_LOG_FILE"
                    grid[$key]="$ERROR_SYMBOL"
                    possibilities[$key]="$ERROR_SYMBOL"
                    collapsed[$key]=1
                    cell_colors[$key]=""
                fi
                continue # Skip this cell for candidate selection
            fi


            if (( entropy > 0 )); then
                if (( entropy < min_entropy )); then
                    min_entropy=$entropy
                    candidates=("$key") # Start new list of candidates
                    lowest_entropy_key=$key # For logging
                     echo "DEBUG (blocky.sh update): New min entropy $entropy found at $key." >> "$DEBUG_LOG_FILE"
                elif (( entropy == min_entropy )); then
                    candidates+=("$key") # Add to existing list
                    # echo "DEBUG (blocky.sh update): Adding candidate $key with entropy $entropy." >> "$DEBUG_LOG_FILE"
                fi
            # No need for explicit entropy == 0 check here, handled by the -z check above
            fi
        fi
    done

    if [[ $all_collapsed -eq 1 ]]; then
        STATUS_MESSAGE="Blocky Shapes Complete!"
        echo "INFO (blocky.sh update): All cells collapsed." >> "$DEBUG_LOG_FILE"
        return 1 # Indicate completion
    fi

    if (( ${#candidates[@]} == 0 )); then
         # This should ideally not happen if there are uncollapsed cells with >0 entropy
         # If it does, it might mean all remaining uncollapsed cells hit a contradiction simultaneously
         STATUS_MESSAGE="Blocky Shapes Error: No valid candidates found!"
         echo "ERROR (blocky.sh update): No candidates found, but not all cells are collapsed. Possible widespread contradiction." >> "$DEBUG_LOG_FILE"
         return 1 # Indicate error/stalemate
    fi

    # Select a candidate cell randomly from the list of minimum entropy cells
    local pick_index=$(( RANDOM % ${#candidates[@]} ))
    local pick="${candidates[$pick_index]}"
    local y="${pick%,*}" x="${pick#*,}"
    local options_str="${possibilities[$pick]}"

    echo "DEBUG (blocky.sh update): Found ${#candidates[@]} candidates with entropy $min_entropy. Picked $pick ('$options_str')." >> "$DEBUG_LOG_FILE"


    # This check should be redundant now due to earlier filtering, but safe to keep
    if [[ -z "$options_str" || "$options_str" == "$ERROR_SYMBOL" ]]; then
        STATUS_MESSAGE="Blocky Error: Picked candidate $pick has no valid options!"
        grid[$pick]="$ERROR_SYMBOL"
        possibilities[$pick]="$ERROR_SYMBOL"
        collapsed[$pick]=1
        cell_colors[$pick]=""
        echo "ERROR (blocky.sh update): Selected candidate $pick '$options_str' is empty or error symbol. Setting to '$ERROR_SYMBOL'." >> "$DEBUG_LOG_FILE"
        # Don't propagate from an error state
        return 0 # Continue algorithm, maybe other parts can resolve
    fi

    # Choose one symbol randomly from the possibilities of the selected cell
    local choice_index=$(( RANDOM % ${#options_str} ))
    local base_symbol="${options_str:$choice_index:1}"

    echo "DEBUG (blocky.sh update): Collapsing $pick to '$base_symbol'" >> "$DEBUG_LOG_FILE"


    # Determine color based on neighbors (only if not collapsing to space)
    local color_id="" # Use "" for no color (space or error)
    if [[ "$base_symbol" != " " ]]; then
        local color1_count=0 color2_count=0
        local neighbor_dirs=("left" "right" "up" "down")
        for dir in "${neighbor_dirs[@]}"; do
            local ny nx
            case "$dir" in
                left)  ny="$y"; nx=$((x - 1)) ;; right) ny="$y"; nx=$((x + 1)) ;;
                up)    ny=$((y - 1)); nx="$x" ;; down)  ny=$((y + 1)); nx="$x" ;;
            esac
            local nkey="$ny,$nx"

            # Check bounds and if neighbor IS collapsed and HAS a color
            if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )) && \
               [[ "${collapsed[$nkey]:-0}" == "1" ]] && \
               [[ -n "${cell_colors[$nkey]}" ]]; then
                local neighbor_color_id="${cell_colors[$nkey]}"
                if [[ "$neighbor_color_id" == "1" ]]; then
                    ((color1_count++))
                elif [[ "$neighbor_color_id" == "2" ]]; then
                    ((color2_count++))
                fi
            fi
        done

        # Choose color: prefer dominant neighbor color, else random
        if (( color1_count > color2_count )); then
            color_id="1"
        elif (( color2_count > color1_count )); then
            color_id="2"
        elif (( color1_count == 0 && color2_count == 0 )); then
             # No colored neighbors, pick randomly
             color_id=$(( RANDOM % 2 + 1 ))
        else # Equal number of neighbors of each color
             color_id=$(( RANDOM % 2 + 1 ))
        fi
        echo "DEBUG (blocky.sh update): Color choice for $pick ('$base_symbol'): C1 neighbors=$color1_count, C2 neighbors=$color2_count -> Chosen Color ID: $color_id" >> "$DEBUG_LOG_FILE"
    else
         echo "DEBUG (blocky.sh update): Collapsing $pick to space, no color needed." >> "$DEBUG_LOG_FILE"
    fi

    # --- Update Grid and State ---
    possibilities[$pick]="$base_symbol"     # Set possibilities to the chosen symbol
    collapsed[$pick]=1                      # Mark cell as collapsed
    cell_colors[$pick]="$color_id"          # Store the chosen color ID (or "" for space)
    grid[$pick]="$base_symbol"              # Store the base symbol in the grid (without ANSI codes)

    # The old logic using color_char is removed.
    # Rendering with color now depends on the engine interpreting grid + cell_colors.

    # Propagate the consequences of this collapse
    propagate "$y" "$x"

    # Update Status Message
    local collapsed_count=0
    for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
    local progress_percent=$(( (collapsed_count * 100) / (ROWS * COLS) ))
    STATUS_MESSAGE="Blocky: Collapsed '$base_symbol' @$pick (Clr $color_id) | $collapsed_count/$((ROWS*COLS)) ($progress_percent%)"

    echo "DEBUG (update_algorithm): grid[$pick]='${grid[$pick]}' at position ($y,$x)" >> "$DEBUG_LOG_FILE"
    echo "DEBUG (update_algorithm): cell_colors[$pick]='${cell_colors[$pick]}'" >> "$DEBUG_LOG_FILE"

    return 0 # Indicate successful step
}

# Note: render_cell and draw_cell are removed as the engine handles rendering.
# Note: set_block, log_contradiction, handle_contradiction, get_neighbors removed as
#       contradiction handling is integrated into propagate/update_algorithm.

export -f color_char
