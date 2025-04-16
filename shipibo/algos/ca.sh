#!/usr/bin/env bash

# --- Game of Life Engine (Refactored) ---

# --- Constants ---
ALIVE='#'
DEAD=' '

# --- Game Symbols Used by Renderer ---
declare -ga SYMBOLS=("$ALIVE" "$DEAD")

# --- Documentation Pages ---
init_docs() {
  PAGES=()
  PAGES+=("Conway's Game of Life: A cell becomes
ALIVE ($ALIVE) if it has exactly 3 ALIVE
neighbors. A cell stays ALIVE ($ALIVE) if it
has 2 or 3 ALIVE neighbors. Otherwise, the
cell becomes DEAD ($DEAD). (Grid shows random
start)")
  PAGES+=("Oscillators: Patterns that return to
original state after some generations, like
Blinker. (Grid shows random start)")
  PAGES+=("Example: Blinker (Period 2)
State 1:
 $ALIVE
 $ALIVE
 $ALIVE
State 2:
$ALIVE $ALIVE $ALIVE
(Grid shows Blinker example)")
  PAGES+=("Still Lifes: Patterns that don't
change from one generation to the next.
(Grid shows random start)")
  PAGES+=("Example: Block (Still Life)
$ALIVE$ALIVE
$ALIVE$ALIVE
Stable pattern due to neighbor saturation.
(Grid shows Block example)")
  PAGES+=("Gliders: Small patterns that move
across the grid periodically.
Example:
 $DEAD$ALIVE$DEAD
 $DEAD$DEAD$ALIVE
 $ALIVE$ALIVE$ALIVE
(Grid shows Glider example)")
  PAGES+=("Generators (Guns): Complex patterns
like the Gosper Glider Gun that emit gliders
periodically. (Grid shows Gun example)")
  PAGES+=("Methuselahs: Small starting patterns
that evolve for many generations.
Example: R-pentomino
 $ALIVE$ALIVE
$ALIVE$ALIVE$DEAD
 $ALIVE
(Grid shows R-pentomino)")
}

# --- Grid Initialization Helpers ---
_clear_grid() {
  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      local key="$y,$x"
      grid["$key"]="$DEAD"
      collapsed["$key"]=1
      possibilities["$key"]=""
    done
  done
}

_init_random() {
  _clear_grid
  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      [[ $((RANDOM % 5)) -eq 0 ]] && grid["$y,$x"]="$ALIVE"
    done
  done
}

_place_cells_relative() {
  local origin_y=$1
  local origin_x=$2
  shift 2
  local coords=("$@")
  for coord in "${coords[@]}"; do
    local dy=${coord%,*}
    local dx=${coord#*,}
    local y=$((origin_y + dy))
    local x=$((origin_x + dx))
    if (( y >= 0 && y < ROWS && x >= 0 && x < COLS )); then
      grid["$y,$x"]="$ALIVE"
    fi
  done
}

_init_pattern_centered() {
  _clear_grid
  local cy=$((ROWS / 2))
  local cx=$((COLS / 2))
  _place_cells_relative "$cy" "$cx" "$@"
}

_init_blinker() {
  _init_pattern_centered "-1,0" "0,0" "1,0"
}

_init_block() {
  _init_pattern_centered "0,0" "0,1" "1,0" "1,1"
}

_init_glider() {
  _clear_grid
  _place_cells_relative 1 1 "0,1" "1,2" "2,0" "2,1" "2,2"
}

_init_r_pentomino() {
  _init_pattern_centered "-1,1" "-1,2" "0,0" "0,1" "1,1"
}

# --- Dispatcher for Grid Initialization ---
init_grid() {
  local idx=${1:-$CURRENT_PAGE}
  case "$idx" in
    2) _init_blinker ;;
    4) _init_block ;;
    5) _init_glider ;;
    7) _init_r_pentomino ;;
    *) _init_random ;;
  esac
  RUNNING=0
  STATUS_MESSAGE="Grid initialized for page $((idx + 1)). Paused."
}

# --- Update CA State ---
update_algorithm() {
  local -A next_grid
  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      local key="$y,$x"
      local state="${grid[$key]}"
      local neighbors=0
      for ((dy=-1; dy<=1; dy++)); do
        for ((dx=-1; dx<=1; dx++)); do
          (( dy == 0 && dx == 0 )) && continue
          local ny=$(((y + dy + ROWS) % ROWS))
          local nx=$(((x + dx + COLS) % COLS))
          [[ "${grid[$ny,$nx]}" == "$ALIVE" ]] && ((neighbors++))
        done
      done
      local next="$DEAD"
      if [[ "$state" == "$ALIVE" ]]; then
        [[ $neighbors -eq 2 || $neighbors -eq 3 ]] && next="$ALIVE"
      else
        [[ $neighbors -eq 3 ]] && next="$ALIVE"
      fi
      next_grid["$key"]="$next"
    done
  done
  for key in "${!next_grid[@]}"; do
    grid["$key"]="${next_grid[$key]}"
  done
  STATUS_MESSAGE="Iteration complete"
  return 0
}

