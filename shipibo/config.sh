# Engine Configuration & State

# Locale settings are now set in simple_engine.sh

# --- Core Engine Configuration ---
ROWS=15
COLS=30
RUNNING=0
SHOULD_EXIT=0
FULL_SCREEN=0         # 0=Small (Side-by-Side), 1=Large (Fullscreen Centered)
EMPTY_DISPLAY=0
LOG_FILE="events.log"

# --- Algorithm Management ---
ALGO_DIR="$SCRIPT_DIR/algos"
mapfile -t ALGO_FILES < <(find "$ALGO_DIR" -maxdepth 1 -type f -name '*.sh' \
  -exec basename {} \; | sort)

CURRENT_ALGO_INDEX=0
ALGO_FILE=""

# --- Algorithm-Provided Data Structures ---
declare -gA grid
declare -gA collapsed
declare -ga PAGES
CURRENT_DOC_PAGE=0

# --- Rendering State ---
declare -g CURRENT_RENDER_FORMAT="ASCII" # Start with ASCII: ASCII, ENHANCED, TILED
declare -gA AVAILABLE_FORMATS=()         # Populated by loader: [ASCII]=1, [ENHANCED]=1, [TILED]=1
declare -gA TILED_RENDER_DATA=()         # Stores data from get_tiled_data: [tile_width], [tile_height], [TILE_TOPS_str], [TILE_BOTS_str], [error_symbol]

# --- Engine Internals ---
declare -ga display_lines                # Used by render_large (Fullscreen)
declare -ga text_lines                   # Used by render_small (Side-by-Side)
declare -gA KEY_ACTIONS
STATUS_MESSAGE=""

# --- Color Definitions (Example - Algos can override/use) ---
COLOR_RESET="\033[0m"
COLOR_RED_FG="31"
COLOR_RED_BG="41"
COLOR_GREEN_FG="32"
COLOR_GREEN_BG="42"
COLOR_YELLOW_FG="33"
COLOR_YELLOW_BG="43"
COLOR_BLUE_FG="34"
COLOR_BLUE_BG="44"
COLOR_MAGENTA_FG="35"
COLOR_MAGENTA_BG="45"
COLOR_CYAN_FG="36"
COLOR_CYAN_BG="46"
COLOR_WHITE_FG="37"
COLOR_WHITE_BG="47"
COLOR_BLACK_FG="30"
COLOR_BLACK_BG="40"
# Function provided for algorithms to use colors easily
color_char() {
    local fg="$1"
    local bg="$2"
    local char="$3"
    printf "\033[%s;%sm%s%s" "$fg" "$bg" "$char" "$COLOR_RESET"
}


