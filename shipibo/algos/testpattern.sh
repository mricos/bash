# --- Test Pattern Algorithm ---
# Demonstrates different rendering modes using semantic states.

# --- Algorithm Specific State ---
# Mode definitions mirroring ca.sh pattern pages
declare -ga TEST_MODES=("DEFAULT" "PATTERN_A" "PATTERN_B" "PATTERN_C")
declare -g CURRENT_TEST_MODE_IDX=0

# --- Engine Hook Functions ---

# Initialize the Base Grid with semantic states
# The specific pattern depends on the CURRENT_TEST_MODE_IDX
init_grid() {
    local mode=${TEST_MODES[$CURRENT_TEST_MODE_IDX]:-"DEFAULT"}
    log_event "TestPattern: Initializing grid for mode '$mode'"
    grid=() # Clear grid
    collapsed=() # WFC remnants, maybe remove if not using?
                 # Keep for now if engine expects it, mark all collapsed.

    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            local state="DEFAULT"
            # Create a simple pattern based on row/column parity and mode
            case "$mode" in
                "PATTERN_A")
                    (( (x / 5 + y / 3) % 2 == 0 )) && state="TEST_A" || state="TEST_B"
                    ;;
                "PATTERN_B")
                     (( (x / 4 + y / 4) % 2 == 0 )) && state="TEST_B" || state="TEST_C"
                    ;;
                "PATTERN_C")
                     (( (x % 7 + y % 5) % 3 == 0 )) && state="TEST_C" || state="TEST_A"
                    ;;
                *)
                    # Default mode: maybe just A/B pattern
                    (( (x / 5 + y / 3) % 2 == 0 )) && state="TEST_A" || state="TEST_B"
                    ;;
            esac
            grid[$key]="$state"
            collapsed[$key]=1 # Mark all cells as collapsed 
        done
    done
    STATUS_MESSAGE="Test Pattern: Mode '$mode' initialized"
    return 0
}

# Return the semantic state for a given cell
# Engine Hook: Return the semantic state for a given cell
get_state() {
    local row=$1
    local col=$2
    local key="$row,$col"
    # Simply return the state stored in the grid
    echo "${grid[$key]:-DEFAULT}" # Return DEFAULT if key missing
}

# Initialize documentation pages (Update to explain modes)
init_docs() {
    PAGES=()
    PAGES+=("$(cat <<'EOF'
TEST PATTERN ALGORITHM (1/3)
---------------------------
Generates simple static patterns based
on coordinates & current test mode.

Demonstrates rendering modes (ASCII,
UTF8_BASIC, UTF8_COLOR) defined in
glyphs.conf & colors.conf.
EOF
)")
    PAGES+=("$(cat <<'EOF'
TEST PATTERN ALGORITHM (2/3)
---------------------------
Use engine keys to cycle:
- Render Modes: '(Prev/Next Mode keys)'
  (e.g., ASCII -> UTF8 -> Color)
- Test Modes (Patterns): '(Prev/Next Algo keys)'
  (Changes the pattern itself)
- Algo: Use standard keys
EOF
)")
    PAGES+=("$(cat <<'EOF'
TEST PATTERN ALGORITHM (3/3)
---------------------------
Semantic States Used:
- TEST_A (+)
- TEST_B (-)
- TEST_C (*)
- DEFAULT (?)

Their appearance depends on the active
Render Mode and glyph/color config.
EOF
)")
}

# Update function - selects next test pattern mode
update_algorithm() {
    # Cycle through test modes instead of doing nothing
    CURRENT_TEST_MODE_IDX=$(( (CURRENT_TEST_MODE_IDX + 1) % ${#TEST_MODES[@]} ))
    init_grid # Re-initialize grid with the new pattern
    STATUS_MESSAGE="Changed test pattern to ${TEST_MODES[$CURRENT_TEST_MODE_IDX]}"
    # Return 0 because we want the engine to re-render the new grid
    # Or return 1 if we consider changing pattern as "one step"?
    # Let's return 1 to make it step-like when running.
    return 1 
}

# Handle input function - maybe use step key?
handle_input() {
    local key_pressed="$1"
    case "$key_pressed" in 
        # Example: Allow forcing next pattern with 's' key if desired
        # s) update_algorithm; return 1 ;; # Signal redraw needed
        *) STATUS_MESSAGE="Key '$key_pressed' not used by TestPattern" ;;
    esac
    return 0 # No redraw needed for unhandled keys
}
