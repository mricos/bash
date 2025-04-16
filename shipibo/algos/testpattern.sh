# --- Test Pattern Algorithm ---
# Demonstrates ASCII, Enhanced, and Tiled rendering formats.

# --- Algorithm Specific State ---
# (None needed for this simple pattern)

# --- Engine Hook Functions ---

# Initialize the Base Grid with a simple pattern
init_grid() {
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            # Create a simple pattern based on row/column parity
            if (( (x / 5 + y / 3) % 2 == 0 )); then
                grid[$key]="+" # Pattern block 1
            else
                grid[$key]="-" # Pattern block 2
            fi
            collapsed[$key]=1 # Mark all cells as collapsed for rendering
        done
    done
    return 0
}

# Return a character for Enhanced view (e.g., add color based on grid value)
get_enhanced_char() {
    local row=$1
    local col=$2
    local collapse_status=$3 # 0 or 1
    local grid_val=$4        # Value from grid array ('+' or '-')

    if [[ "$collapse_status" == "1" ]]; then
        if [[ "$grid_val" == "+" ]]; then
             # Use magenta for '+'
             # Need color_char function from engine_config_state.sh
             if declare -F color_char &>/dev/null; then
                 color_char "$COLOR_MAGENTA_FG" "$COLOR_BLACK_BG" "+"
             else
                 echo "+" # Fallback if color function missing
             fi
        elif [[ "$grid_val" == "-" ]]; then
             # Use cyan for '-'
             if declare -F color_char &>/dev/null; then
                 color_char "$COLOR_CYAN_FG" "$COLOR_BLACK_BG" "-"
             else
                 echo "-" # Fallback
             fi
        else
             echo "?" # Unknown grid value
        fi
    else
         # Uncollapsed cell: Use space or dot based on engine state
         if [[ $EMPTY_DISPLAY -eq 1 ]]; then echo " "; else echo "·"; fi
    fi
}


# Provide data needed for Tiled rendering
get_tiled_data() {
    # Define simple 2-width, 1-height tiles
    local tile_width=2
    local tile_height=1
    local error_symbol="!!" # Use two chars to match width

    # Define tile graphics (associative arrays)
    # Keys match the grid values (+, -)
    local -A TILE_TOPS=(
        ['+']="++"
        ['-']="--"
    )
    # Since height is 1, TILE_BOTS can be empty or mirror TOPS
    local -A TILE_BOTS=()

    # Output the declarations using 'declare -p'
    declare -p tile_width tile_height error_symbol TILE_TOPS TILE_BOTS
}


# Initialize documentation pages
init_docs() {
    PAGES=() # Clear/initialize pages array
    PAGES+=("$(cat <<'EOF'
TEST PATTERN ALGORITHM (1/2)
---------------------------
This algorithm generates a simple static
pattern based on grid coordinates.

Its purpose is to demonstrate the
different rendering formats:
- ASCII: Shows '+' and '-'
- Enhanced: Adds color to '+' and '-'
- Tiled: Uses simple 2x1 tiles '++' '--'
EOF
)")
    PAGES+=("$(cat <<'EOF'
TEST PATTERN ALGORITHM (2/2)
---------------------------
Use 'u'/'i' to cycle through formats
(ASCII -> Enhanced -> Tiled -> ASCII).

In fullscreen mode ('f' to toggle),
use Arrow Keys:
- Left/Right: Change Algorithm
- Up/Down: Change Format

This algorithm does not update ('c'/'Space').
EOF
)")
}

# Update function - does nothing for this static pattern
update_algorithm() {
    # No state change, just signal to stop running if started
    STATUS_MESSAGE="Pattern is static. Press Space to pause."
    return 1 # Signal to stop running immediately
}

# Handle input function - does nothing specific for this algo
handle_input() {
    local key_pressed="$1"
    # No keys handled directly by this algorithm
    STATUS_MESSAGE="Key '$key_pressed' not used by TestPattern"
    log_event "TestPattern received key '$key_pressed', ignoring."
}
