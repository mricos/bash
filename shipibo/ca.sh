#!/usr/bin/env bash

# Conway's Game of Life for simple_engine.sh

# --- Symbols and Rules ---
ALIVE='#'
DEAD=' '

export SYMBOLS=("$ALIVE" "$DEAD")   # Symbols used in the CA (e.g., space for dead, 'X' for alive)

# --- Initialize Global Variables ---
declare -gA grid           # Stores plain symbols
declare -gA cell_colors    # Stores color IDs for each cell
declare -gA next_grid      # For computing the next generation

# Color Definitions
COLOR_DEAD_FG="30"    # Black foreground
COLOR_DEAD_BG="47"    # White background
COLOR_ALIVE_FG="37"   # White foreground
COLOR_ALIVE_BG="40"   # Black background

# Helper to apply ANSI colors
color_char() {
    local fg_color="$1"
    local bg_color="$2"
    local char="$3"
    echo -e "\033[${fg_color};${bg_color}m${char}\033[0m"
}
export -f color_char  # Export if needed by the engine

init_rules() {
    # Define the symbols used by the renderer
    echo "INFO (ca.sh): Initialized Game of Life rules." >> "$DEBUG_LOG_FILE"

    # Define documentation pages
    PAGES=(
# Page 1
"Conway's Game of Life:
 A cell becomes ALIVE ($ALIVE) if it has exactly 3 ALIVE neighbors.
 A cell stays ALIVE ($ALIVE) if it has 2 or 3 ALIVE neighbors.
 Otherwise, the cell becomes DEAD ($DEAD).
 (Grid shows random start)"

# Page 2
"Oscillators:
 Oscillators are patterns that return to their original state
 after a finite number of generations (the period).
 They are common stable structures in Game of Life.
 (Grid shows random start)"

# Page 3
"Example: Blinker (Period 2)

 State 1:    State 2:

   $ALIVE         $DEAD $ALIVE $DEAD
   $ALIVE
   $ALIVE

 This simple pattern flips between vertical and horizontal.
 (Grid shows Blinker example)"

# Page 4
"Still Lifes:
 Still lifes are patterns that do not change from one
 generation to the next.
 They have reached a stable state where no cells will be
 born or die.
 (Grid shows random start)"

# Page 5
"Example: Block (Still Life)

   $ALIVE$ALIVE
   $ALIVE$ALIVE

 Each alive cell has exactly 3 alive neighbors, so it
 survives. All dead neighbors have fewer than 3 alive
 neighbors, so they remain dead.
 (Grid shows Block example)"

# Page 6
"Gliders:
 Gliders are patterns that move across the grid.
 They are the smallest spaceships and repeat their shape
 every 4 generations, shifted diagonally.
 Example:
   .$ALIVE.
   ..$ALIVE
   $ALIVE$ALIVE$ALIVE
 (Grid shows Glider example)"

# Page 7
"Generators (Guns):
 Generators are patterns that repeatedly create other
 patterns, typically spaceships like gliders.
 The most famous is the Gosper Glider Gun, which produces
 a new glider every 30 generations.
 These patterns are often large and complex.
 (Grid shows random start)"

# Page 8
"Methuselahs:
 These are small starting patterns that evolve for a large
 number of steps before stabilizing, often creating many
 temporary structures (gliders, blocks, etc.).
 Example: R-pentomino (stabilizes after 1103 steps!)
   .$ALIVE$ALIVE
   $ALIVE$ALIVE.
   .$ALIVE.
 (Grid shows R-pentomino example)"
    )
     echo "DEBUG (ca.sh): Set ${#PAGES[@]} documentation pages." >> "$DEBUG_LOG_FILE"
}

# --- Grid Initialization Helpers ---

# Helper to clear grid and set base properties
_clear_grid() {
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            grid["$key"]="$DEAD"
            cell_colors[$key]="dead"
            collapsed["$key"]=1 # All cells 'collapsed' initially
            possibilities["$key"]="" # Not used
        done
    done
}

# Helper for random initialization
_init_random() {
    echo "INFO (ca.sh): Initializing Game of Life grid (${ROWS}x${COLS}) with random pattern." >> "$DEBUG_LOG_FILE"
    _clear_grid
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            # Randomly initialize ~20% of cells as alive
            if [[ $((RANDOM % 5)) -eq 0 ]]; then
                grid["$key"]="$ALIVE"
                cell_colors[$key]="alive"
            fi
        done
    done
     echo "DEBUG (ca.sh): Grid initialized with random pattern." >> "$DEBUG_LOG_FILE"
}

# Helper for Blinker initialization
_init_blinker() {
     echo "INFO (ca.sh): Initializing Game of Life grid (${ROWS}x${COLS}) with Blinker pattern." >> "$DEBUG_LOG_FILE"
     _clear_grid
     local center_y=$((ROWS / 2))
     local center_x=$((COLS / 2))
     # Place the Blinker pattern (vertical line), checking bounds
     if (( center_y > 0 && center_y < ROWS-1 && center_x >= 0 && center_x < COLS )); then
        grid["$((center_y - 1)),$center_x"]="$ALIVE"
        grid["$center_y,$center_x"]="$ALIVE"
        grid["$((center_y + 1)),$center_x"]="$ALIVE"
        cell_colors[$((center_y - 1)),$center_x]="alive"
        cell_colors[$center_y,$center_x]="alive"
        cell_colors[$((center_y + 1)),$center_x]="alive"
        echo "DEBUG (ca.sh): Placed Blinker at ($((center_y-1)),$center_x) to ($((center_y+1)),$center_x)." >> "$DEBUG_LOG_FILE"
    else
        echo "WARN (ca.sh): Grid too small to place Blinker pattern near center. Placing single cell." >> "$DEBUG_LOG_FILE"
        if (( ROWS > 0 && COLS > 0 )); then grid["0,0"]="$ALIVE"; fi # Fallback
    fi
    echo "DEBUG (ca.sh): Grid initialized with Blinker pattern." >> "$DEBUG_LOG_FILE"
}

# Helper for Block initialization
_init_block() {
    echo "INFO (ca.sh): Initializing Game of Life grid (${ROWS}x${COLS}) with Block pattern." >> "$DEBUG_LOG_FILE"
     _clear_grid
    local center_y=$(( (ROWS / 2) - 1 ))
    local center_x=$(( (COLS / 2) - 1 ))
    # Place the Block pattern (2x2), checking bounds
    if (( center_y >= 0 && center_y < ROWS-1 && center_x >= 0 && center_x < COLS-1 )); then
        grid["$center_y,$center_x"]="$ALIVE"
        grid["$center_y,$((center_x + 1))"]="$ALIVE"
        grid["$((center_y + 1)),$center_x"]="$ALIVE"
        grid["$((center_y + 1)),$((center_x + 1))"]="$ALIVE"
        cell_colors[$center_y,$center_x]="alive"
        cell_colors[$center_y,$((center_x + 1))]="alive"
        cell_colors[$((center_y + 1)),$center_x]="alive"
        cell_colors[$((center_y + 1)),$((center_x + 1))]="alive"
        echo "DEBUG (ca.sh): Placed Block at ($center_y,$center_x)." >> "$DEBUG_LOG_FILE"
    else
        echo "WARN (ca.sh): Grid too small to place Block pattern near center. Placing single cell." >> "$DEBUG_LOG_FILE"
        if (( ROWS > 0 && COLS > 0 )); then grid["0,0"]="$ALIVE"; fi # Fallback
    fi
    echo "DEBUG (ca.sh): Grid initialized with Block pattern." >> "$DEBUG_LOG_FILE"
}

# Helper for Glider initialization
_init_glider() {
    echo "INFO (ca.sh): Initializing Game of Life grid (${ROWS}x${COLS}) with Glider pattern." >> "$DEBUG_LOG_FILE"
    _clear_grid
    # Position near top-left for visibility
    local start_y=1
    local start_x=1

    # Glider pattern relative coordinates (y, x)
    # .#.  -> (0, 1)
    # ..#  -> (1, 2)
    # ###  -> (2, 0), (2, 1), (2, 2)
    local glider_coords=("0,1" "1,2" "2,0" "2,1" "2,2")

    local can_place=1
    # Check bounds first
    for coord in "${glider_coords[@]}"; do
        local rel_y=${coord%,*}
        local rel_x=${coord#*,}
        local y=$((start_y + rel_y))
        local x=$((start_x + rel_x))
        if (( y < 0 || y >= ROWS || x < 0 || x >= COLS )); then
            can_place=0
            break
        fi
    done

    if [[ $can_place -eq 1 ]]; then
        for coord in "${glider_coords[@]}"; do
            local rel_y=${coord%,*}
            local rel_x=${coord#*,}
            local y=$((start_y + rel_y))
            local x=$((start_x + rel_x))
            grid["$y,$x"]="$ALIVE"
            cell_colors[$y,$x]="alive"
        done
        echo "DEBUG (ca.sh): Placed Glider starting near ($start_y,$start_x)." >> "$DEBUG_LOG_FILE"
    else
        echo "WARN (ca.sh): Grid too small to place Glider pattern near top-left. Placing single cell." >> "$DEBUG_LOG_FILE"
        if (( ROWS > 0 && COLS > 0 )); then grid["0,0"]="$ALIVE"; fi # Fallback
    fi
    echo "DEBUG (ca.sh): Grid initialized with Glider pattern." >> "$DEBUG_LOG_FILE"
}

# Helper for R-pentomino initialization
_init_r_pentomino() {
    echo "INFO (ca.sh): Initializing Game of Life grid (${ROWS}x${COLS}) with R-pentomino pattern." >> "$DEBUG_LOG_FILE"
    _clear_grid
    # Position near the center
    local center_y=$((ROWS / 2))
    local center_x=$((COLS / 2))

    # R-pentomino relative coordinates (y, x) from center
    # ..$# -> (0, 1), (0, 2)
    # .##. -> (1, 0), (1, 1)
    # ..#. -> (2, 1)
    # Adjusting slightly for better centering of the 3x3 bounding box
    local r_coords=("-1,1" "-1,2" "0,0" "0,1" "1,1")

    local can_place=1
    # Check bounds first
    for coord in "${r_coords[@]}"; do
        local rel_y=${coord%,*}
        local rel_x=${coord#*,}
        local y=$((center_y + rel_y))
        local x=$((center_x + rel_x))
        if (( y < 0 || y >= ROWS || x < 0 || x >= COLS )); then
            can_place=0
            break
        fi
    done

    if [[ $can_place -eq 1 ]]; then
        for coord in "${r_coords[@]}"; do
            local rel_y=${coord%,*}
            local rel_x=${coord#*,}
            local y=$((center_y + rel_y))
            local x=$((center_x + rel_x))
            grid["$y,$x"]="$ALIVE"
            cell_colors[$y,$x]="alive"
        done
        echo "DEBUG (ca.sh): Placed R-pentomino centered near ($center_y,$center_x)." >> "$DEBUG_LOG_FILE"
    else
        echo "WARN (ca.sh): Grid too small to place R-pentomino pattern near center. Placing single cell." >> "$DEBUG_LOG_FILE"
        if (( ROWS > 0 && COLS > 0 )); then grid["0,0"]="$ALIVE"; fi # Fallback
    fi
    echo "DEBUG (ca.sh): Grid initialized with R-pentomino pattern." >> "$DEBUG_LOG_FILE"
}

# --- Grid Initialization Dispatcher ---
# Called by simple_engine.sh on load and on page change for ca.sh
init_grid() {
    local page_index_to_use=${1:-$CURRENT_PAGE} # Use passed index or global
    echo "DEBUG (ca.sh init_grid): Initializing for page index ${page_index_to_use}." >> "$DEBUG_LOG_FILE"
    case "$page_index_to_use" in
        2) # Page 3 - Blinker Example
            _init_blinker
            ;;
        4) # Page 5 - Block Example
            _init_block
            ;;
        5) # Page 6 - Glider Example
            _init_glider
            ;;
        7) # Page 8 - R-pentomino Example
            _init_r_pentomino
            ;;
        *) # Default / Other pages
            _init_random
            ;;
    esac
    # Ensure simulation starts paused after re-init based on page
    RUNNING=0
    STATUS_MESSAGE="Grid initialized for page $((page_index_to_use + 1)). Paused."
}

# --- Algorithm Update Step ---
update_algorithm() {
    # echo "DEBUG (ca.sh): Starting Game of Life update step." >> "$DEBUG_LOG_FILE"
    next_grid=()
    local changes=0

    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            local current_state="${grid[$key]}"
            local alive_neighbors=0

            # Count alive neighbors (Moore neighborhood, wrapping around edges)
            for ((dy=-1; dy<=1; dy++)); do
                for ((dx=-1; dx<=1; dx++)); do
                    # Skip the cell itself
                    if [[ $dx -eq 0 && $dy -eq 0 ]]; then continue; fi

                    local ny=$(( (y + dy + ROWS) % ROWS )) # Wrap vertically
                    local nx=$(( (x + dx + COLS) % COLS )) # Wrap horizontally
                    local nkey="$ny,$nx"

                    if [[ "${grid[$nkey]}" == "$ALIVE" ]]; then
                        ((alive_neighbors++))
                    fi
                done
            done

            # Apply Game of Life rules
            local next_state="$DEAD" # Default to dead
            if [[ "$current_state" == "$ALIVE" ]]; then
                if [[ $alive_neighbors -eq 2 || $alive_neighbors -eq 3 ]]; then
                    next_state="$ALIVE" # Survival
                fi
            else # Current state is DEAD
                if [[ $alive_neighbors -eq 3 ]]; then
                    next_state="$ALIVE" # Birth
                fi
            fi
            next_grid["$key"]="$next_state"
            if [[ "$next_state" != "$current_state" ]]; then
                cell_colors[$key]="${cell_colors[$key]#*_}"
                if [[ "$next_state" == "$ALIVE" ]]; then
                    cell_colors[$key]+="alive"
                else
                    cell_colors[$key]+="dead"
                fi
                ((changes++))
            fi
        done
    done

    # Update the main grid from the temporary grid
    for key in "${!next_grid[@]}"; do
        grid["$key"]="${next_grid[$key]}"
    done

    # echo "DEBUG (ca.sh): Game of Life update step finished." >> "$DEBUG_LOG_FILE"
    STATUS_MESSAGE="CA Updated: $changes changes"
    return 0 # Indicate success / continue running
}

# Ensure color definitions are exported if needed
export COLOR_DEAD_FG COLOR_DEAD_BG COLOR_ALIVE_FG COLOR_ALIVE_BG

# --- Provide Documentation Pages (Optional) ---
PAGES=(
    "CELLULAR AUTOMATA

A simple implementation of
Conway's Game of Life."
) 