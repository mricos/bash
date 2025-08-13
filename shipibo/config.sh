# Engine Configuration & State

# Locale settings are now set in simple_engine.sh

# --- Core Engine Configuration ---
ROWS=16
COLS=16
RUNNING=0
SHOULD_EXIT=0
FULL_SCREEN=0         # DEFAULT: 0=Small (Side-by-Side), 1=Large (Fullscreen Centered)
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
declare -gA possibilities # Needed by blocky
declare -gA cell_colors   # Needed by blocky
declare -ga PAGES
CURRENT_DOC_PAGE=0

# --- Rendering State ---
# Render Modes: ASCII, UTF8_BASIC, UTF8_COLOR, EMOJI (define in glyphs.conf)
declare -g CURRENT_RENDER_MODE="UTF8_COLOR" # Set default mode
declare -g ERROR_SYMBOL="X"             # Default symbol for errors

# --- Engine Internals ---
declare -ga display_lines                # Populated by rendering engine
declare -ga text_lines                   # Used by render_small (Side-by-Side INFO PANEL)
declare -gA KEY_ACTIONS                  # Populated by loader: Maps raw key -> action string
declare -gA KEY_LABELS                   # Populated by loader: Maps raw key -> description string
declare -gA RAW_KEY_MAPPINGS           # Populated by loader: Maps raw key -> full config line
declare -g ENABLE_BACKTRACKING=0       # Algorithm Feature Toggle (0=Disabled, 1=Enabled)
STATUS_MESSAGE=""
declare -g BLOCKY_RULE_MODE=0          # Blocky Algo Rule Mode (0=Default, 1=Alternate)

# --- Terminal Control (using tput) ---
# Reset all attributes
COLOR_RESET=$(tput sgr0 2>/dev/null || echo -e "\033[0m")
# Dim style for status line
STATUS_DIM=$(tput dim 2>/dev/null || echo "") # Fallback to no style if dim not supported

# --- LEGACY Color Definitions REMOVED ---
# Colors are now managed by engine/glyph.sh using colors.conf

# --- LEGACY color_char function REMOVED ---


