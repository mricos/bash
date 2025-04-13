#!/bin/bash
export LC_ALL=C.UTF-8 # Ensure UTF-8 locale

# grid2-shapes.sh - Deterministically generates predefined shapes
# using the grid2.sh tile definitions to test rendering and connections.

# --- Algorithm Metadata ---
export ALGO_TILE_WIDTH=2
export ALGO_TILE_HEIGHT=2

# --- Rendering Glyphs (Copied from grid2.sh) ---
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
TILE_TOPS["T_NORTH"]=" ║   ║ "; TILE_BOTS["T_NORTH"]="═╩═ ═══"
TILE_TOPS["T_EAST"]=" ║     "; TILE_BOTS["T_EAST"]=" ╠═ ═══"
TILE_TOPS["T_SOUTH"]="═╦═ ═══"; TILE_BOTS["T_SOUTH"]=" ║   ║ "
TILE_TOPS["T_WEST"]="    ║ "; TILE_BOTS["T_WEST"]="═══ ═╣ "

# --- Character Mapping (Copied from grid2.sh) ---
declare -gA TILE_NAME_TO_CHAR
TILE_NAME_TO_CHAR["STRAIGHT_H"]="H"; TILE_NAME_TO_CHAR["STRAIGHT_V"]="V"
TILE_NAME_TO_CHAR["BEND_NE"]="N"; TILE_NAME_TO_CHAR["BEND_NW"]="W"
TILE_NAME_TO_CHAR["BEND_SE"]="S"; TILE_NAME_TO_CHAR["BEND_SW"]="T"
TILE_NAME_TO_CHAR["CROSS"]="C"
TILE_NAME_TO_CHAR["T_NORTH"]="U"; TILE_NAME_TO_CHAR["T_EAST"]="R"
TILE_NAME_TO_CHAR["T_SOUTH"]="D"; TILE_NAME_TO_CHAR["T_WEST"]="L"
TILE_NAME_TO_CHAR["ERROR"]="×"
export TILE_NAME_TO_CHAR

# Reverse mapping (optional internal use)
declare -gA CHAR_TO_TILE_NAME
for name in "${!TILE_NAME_TO_CHAR[@]}"; do CHAR_TO_TILE_NAME[${TILE_NAME_TO_CHAR[$name]}]="$name"; done

# --- Core Setup ---
# SYMBOLS not strictly needed for generation, but keep for consistency
export SYMBOLS=("STRAIGHT_H" "STRAIGHT_V" "BEND_NE" "BEND_NW" "BEND_SE" "BEND_SW" "CROSS" "T_NORTH" "T_EAST" "T_SOUTH" "T_WEST")
# Define the internal representation for errors (shouldn't be needed here)
export ERROR_SYMBOL="ERROR"

# Define the shapes to generate via PAGES
PAGES=(
"Shape: Horizontal Line"
"Shape: Vertical Line"
"Shape: NE Corner"
"Shape: NW Corner"
"Shape: SE Corner"
"Shape: SW Corner"
"Shape: Cross"
"Shape: T-North"
"Shape: T-East"
"Shape: T-South"
"Shape: T-West"
"Shape: All Tiles"
)
export PAGES

# ───── Helper Functions ─────

# Helper to set a specific tile in the grid
_set_tile() {
    local y="$1" x="$2" name="$3" 
    local key="$y,$x" # Build key from arguments
    local char="${TILE_NAME_TO_CHAR[$name]:-?}" # Get char for possibilities

    # Check bounds
    if (( y >= 0 && y < ROWS && x >= 0 && x < COLS )); then
        grid["$key"]="$name"
        possibilities["$key"]="$char"
        collapsed["$key"]=1 # Mark as collapsed
        echo "DEBUG (_set_tile): Set $key (y=$y, x=$x) to Name='$name', Char='$char', Collapsed=1" >> "$DEBUG_LOG_FILE"
    else
        echo "WARN (_set_tile): Coordinates ($y,$x) out of bounds for Name='$name'." >> "$DEBUG_LOG_FILE"
    fi
}

# ───── Engine-Called Functions ─────

# Ensure arrays are exported before use by engine
export TILE_TOPS TILE_BOTS TILE_NAME_TO_CHAR 

# Initialize rules - not used for generation, but needed by engine structure
init_rules() {
    rules=() # Clear global rules (no rules needed for shape generation)
    echo "INFO (grid2-shapes.sh): Rules initialized (no-op)." >> "$DEBUG_LOG_FILE"
}

# Initialize grid: Generate a specific shape based on CURRENT_PAGE
init_grid() {
    grid=(); possibilities=(); collapsed=()
    local page_index=${CURRENT_PAGE:-0} # Use global CURRENT_PAGE
    local num_pages=${#PAGES[@]}
    local all_tiles_page_index=$((num_pages - 1)) # Index of the new "All Tiles" page

    echo "INFO (grid2-shapes.sh): Initializing grid for shape page ${page_index}." >> "$DEBUG_LOG_FILE"

    # Set default for all cells (uncollapsed) - IMPORTANT for rendering
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            # Set reasonable defaults for rendering uncollapsed cells
            grid[$key]="UNCOLLAPSED" 
            possibilities[$key]="." 
            collapsed[$key]=0
        done
    done

    # --- Generate Shape based on Page ---
    local mid_y=$((ROWS / 2))
    local mid_x=$((COLS / 2))

    case $page_index in
        0) # Horizontal Line
            STATUS_MESSAGE="Shape: Horizontal Line"
            _set_tile $mid_y $((mid_x - 2)) "STRAIGHT_H"
            _set_tile $mid_y $((mid_x - 1)) "STRAIGHT_H"
            _set_tile $mid_y $mid_x         "STRAIGHT_H"
            _set_tile $mid_y $((mid_x + 1)) "STRAIGHT_H"
            _set_tile $mid_y $((mid_x + 2)) "STRAIGHT_H"
            ;;
        1) # Vertical Line
            STATUS_MESSAGE="Shape: Vertical Line"
            _set_tile $((mid_y - 2)) $mid_x "STRAIGHT_V"
            _set_tile $((mid_y - 1)) $mid_x "STRAIGHT_V"
            _set_tile $mid_y         $mid_x "STRAIGHT_V"
            _set_tile $((mid_y + 1)) $mid_x "STRAIGHT_V"
            _set_tile $((mid_y + 2)) $mid_x "STRAIGHT_V"
            ;;
        2) # NE Corner
            STATUS_MESSAGE="Shape: NE Corner"
            _set_tile $mid_y $mid_x "BEND_NE"
            ;;
        3) # NW Corner
            STATUS_MESSAGE="Shape: NW Corner"
            _set_tile $mid_y $mid_x "BEND_NW"
            ;;
        4) # SE Corner
            STATUS_MESSAGE="Shape: SE Corner"
            _set_tile $mid_y $mid_x "BEND_SE"
            ;;
        5) # SW Corner
            STATUS_MESSAGE="Shape: SW Corner"
            _set_tile $mid_y $mid_x "BEND_SW"
            ;;
        6) # Cross
            STATUS_MESSAGE="Shape: Cross"
            _set_tile $mid_y $mid_x "CROSS"
            ;;
        7) # T-North
            STATUS_MESSAGE="Shape: T-North"
            _set_tile $mid_y $mid_x "T_NORTH"
            ;;
        8) # T-East
            STATUS_MESSAGE="Shape: T-East"
            _set_tile $mid_y $mid_x "T_EAST"
            ;;
        9) # T-South
            STATUS_MESSAGE="Shape: T-South"
            _set_tile $mid_y $mid_x "T_SOUTH"
            ;;
        10) # T-West
            STATUS_MESSAGE="Shape: T-West"
            _set_tile $mid_y $mid_x "T_WEST"
            ;;
        "$all_tiles_page_index") # Dynamically use the last page index
            local start_y=2
            local start_x=3
            local spacing_x=4 # Horizontal space between tiles
            local spacing_y=3 # Vertical space between rows

            # Row 1: Straights
            _set_tile $start_y $start_x "STRAIGHT_H"
            _set_tile $start_y $((start_x + spacing_x)) "STRAIGHT_V"

            # Row 2: Bends
            local y2=$((start_y + spacing_y))
            _set_tile $y2 $start_x                "BEND_NE"
            _set_tile $y2 $((start_x + spacing_x)) "BEND_NW"
            _set_tile $y2 $((start_x + 2*spacing_x)) "BEND_SE"
            _set_tile $y2 $((start_x + 3*spacing_x)) "BEND_SW"
            
            # Add explicit debug for BEND_SW
            echo "DEBUG (init_grid All Tiles): BEND_SW TOP='${TILE_TOPS["BEND_SW"]}', BOT='${TILE_BOTS["BEND_SW"]}'" >> "$DEBUG_LOG_FILE"

            # Row 3: T-Junctions
            local y3=$((y2 + spacing_y))
            _set_tile $y3 $start_x                "T_NORTH"
            _set_tile $y3 $((start_x + spacing_x)) "T_EAST"
            _set_tile $y3 $((start_x + 2*spacing_x)) "T_SOUTH"
            _set_tile $y3 $((start_x + 3*spacing_x)) "T_WEST"
            
            # Add explicit debug for T_WEST
            echo "DEBUG (init_grid All Tiles): T_WEST TOP='${TILE_TOPS["T_WEST"]}', BOT='${TILE_BOTS["T_WEST"]}'" >> "$DEBUG_LOG_FILE"

            # Row 4: Cross
            local y4=$((y3 + spacing_y))
            _set_tile $y4 $start_x "CROSS"
            ;;
        *)
            STATUS_MESSAGE="Shape: Unknown (Page ${page_index})"
            ;;
    esac

    RUNNING=0 # Shapes are static
    echo "INFO (grid2-shapes.sh): Grid initialized with shape: $STATUS_MESSAGE" >> "$DEBUG_LOG_FILE"
}

# Re-export the glyph arrays to ensure they're available to the engine
export TILE_TOPS TILE_BOTS

# Update Algorithm - Does nothing for static shapes
update_algorithm() {
    STATUS_MESSAGE="Shape: ${PAGES[$CURRENT_PAGE]:-Unknown}" # Update status with current shape name
    return 1 # Indicate completion immediately
}

# End of grid2-shapes.sh
