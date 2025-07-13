#!/usr/bin/env bash

# --- WFC: Blocky ASCII Shapes Generator ---
# Generates visual grid patterns using block characters and WFC logic.

# --- Configuration ---
export SYMBOLS=( "▀" "▄" "▌" "▐" "█" " " )
export ERROR_SYMBOL="X"
export ALGO_TILE_WIDTH=1
export ALGO_TILE_HEIGHT=1

# --- Mode Names ---
declare -ga BLOCKY_MODE_NAMES=("Vertical" "Isolated" "Stripes")

# --- Documentation Pages ---
export PAGES=(
  "BLOCKY SHAPES

Uses block characters (▀ ▄ ▌ ▐ █) and space.

The Wave Function Collapse (WFC) algorithm generates
structured grid patterns by applying connection constraints and propagating limits."

  "HOW IT WORKS
1. Each cell begins with all symbols available.

2. Rules determine symbol adjacency compatibility.

3. Minimum entropy heuristic selects a cell to collapse.

+  Entropy here means the number of possible symbols
+  a cell can still become. The algorithm picks the
+  cell with the fewest remaining options (lowest
+  entropy) to decide its state next. This helps
+  guide the generation towards a consistent state.
4. Result is propagated to neighbors, reducing options."

  "RULES: CONNECTIVITY
★ █: connects in all directions.
★ ▀ ▄ ▌ ▐: constrained to halves.
★ ' ': neutral (connects to all).

✔ Valid: ▀ above ▄, ▌ beside ▐
✖ Invalid: ▀ above space"

  "SYMBOLS KEY
█ - Full block
▀ - Upper half
▄ - Lower half
▌ - Left half
▐ - Right half
  - Empty space"

  "RULE EXAMPLE: Propagation

Consider a 3x3 area. Cell (1,1) is chosen
and collapsed to '▀' (Upper Half).

Before propagation, cell (0,1) above it
has possibilities: [▀ ▄ ▌ ▐ █  ]

The '▀' in (1,1) looks at its 'up' rule:
  rules[SYM_UP_HALF_up] = '█ ▄  '

This constraint is applied to (0,1). Only
symbols allowed by the rule remain.

After propagation from (1,1):
  Possibilities(0,1) = [█ ▄  ]

Propagation continues to other neighbors."

  "ALTERNATE MODE (ISOLATED)

Press 'u' to toggle between rule modes.
Mode 0 (Default): Favors vertical lines.
Mode 1 (Alternate): Favors isolated shapes.

Rules for Mode 1:
- Space connects to anything.
- All block symbols (█ ▀ ▄ ▌ ▐) ONLY
  connect to Space.
This results in shapes separated by gaps."

  "MODE 2: STRIPES

Press 'u' to cycle modes (0, 1, 2).
Mode 2 favors vertical or horizontal lines,
assigning colors based on orientation.

Rules for Mode 2:
- Space connects to anything.
- Vert Syms (▀▄█) connect vertically to
  each other or space; only to space horiz.
- Horiz Syms (▌▐) connect horizontally to
  each other or space; only to space vert.
- █ can bridge connections.

Color Assignment:
- Vertical Syms (▀▄█) -> Color 1
- Horizontal Syms (▌▐) -> Color 2"
)

# --- Rule Definitions ---
init_rules() {
  declare -gA rules
  rules=()
  # Define symbolic names once
  local SYM_UP_HALF="SYM_UP_HALF"
  local SYM_DOWN_HALF="SYM_DOWN_HALF"
  local SYM_FULL="SYM_FULL"
  local SYM_SPACE="SYM_SPACE"
  local SYM_LEFT_HALF="SYM_LEFT_HALF"
  local SYM_RIGHT_HALF="SYM_RIGHT_HALF"

  # Define connection groups
  local vertical_syms="▀▄█ "
  local horizontal_syms="▌▐█ "

  rules=() # Clear rules
  local all="▀ ▄ ▌ ▐ █ "
  local space_only=" "

  # Check the global mode variable (set by input action)
  if [[ ${BLOCKY_RULE_MODE:-0} -eq 1 ]]; then
    # Mode 1: Isolation Rules
    log_event "BLOCKY: Initializing ISOLATION rules (Mode 1)"

    # Space connects to everything
    for dir in left right up down; do
      rules["${SYM_SPACE}_$dir"]="$all"
    done
    # All block symbols ONLY connect to space
    for dir in left right up down; do
      rules["${SYM_FULL}_$dir"]="$space_only"
      rules["${SYM_UP_HALF}_$dir"]="$space_only"
      rules["${SYM_DOWN_HALF}_$dir"]="$space_only"
      rules["${SYM_LEFT_HALF}_$dir"]="$space_only"
      rules["${SYM_RIGHT_HALF}_$dir"]="$space_only"
    done

  elif [[ ${BLOCKY_RULE_MODE:-0} -eq 2 ]]; then
    # Mode 2: "Stripes" Rules
    log_event "BLOCKY: Initializing STRIPES rules (Mode 2)"

    # Space connects to everything
    for dir in left right up down; do rules["${SYM_SPACE}_$dir"]="$all"; done

    # Vertical Symbols (▀, ▄)
    rules["${SYM_UP_HALF}_up"]="$vertical_syms"
    rules["${SYM_UP_HALF}_down"]="$vertical_syms"
    rules["${SYM_UP_HALF}_left"]="$space_only"
    rules["${SYM_UP_HALF}_right"]="$space_only"
    rules["${SYM_DOWN_HALF}_up"]="$vertical_syms"
    rules["${SYM_DOWN_HALF}_down"]="$vertical_syms"
    rules["${SYM_DOWN_HALF}_left"]="$space_only"
    rules["${SYM_DOWN_HALF}_right"]="$space_only"

    # Horizontal Symbols (▌, ▐)
    rules["${SYM_LEFT_HALF}_left"]="$horizontal_syms"
    rules["${SYM_LEFT_HALF}_right"]="$horizontal_syms"
    rules["${SYM_LEFT_HALF}_up"]="$space_only"
    rules["${SYM_LEFT_HALF}_down"]="$space_only"
    rules["${SYM_RIGHT_HALF}_left"]="$horizontal_syms"
    rules["${SYM_RIGHT_HALF}_right"]="$horizontal_syms"
    rules["${SYM_RIGHT_HALF}_up"]="$space_only"
    rules["${SYM_RIGHT_HALF}_down"]="$space_only"

    # Full Block (█) - Can bridge orientations
    rules["${SYM_FULL}_up"]="$vertical_syms"
    rules["${SYM_FULL}_down"]="$vertical_syms"
    rules["${SYM_FULL}_left"]="$horizontal_syms"
    rules["${SYM_FULL}_right"]="$horizontal_syms"

  else
    # Mode 0: Vertical Preference Rules (Default)
    log_event "BLOCKY: Initializing VERTICAL rules (Mode 0)"

    # Space and Full block connect to everything (mostly)
    for dir in left right up down; do
      rules["${SYM_FULL}_$dir"]="$all"
      rules["${SYM_SPACE}_$dir"]="$all"
    done

    # Define rules for half blocks
    rules["${SYM_UP_HALF}_left"]="$all"
    rules["${SYM_UP_HALF}_right"]="$all"
    rules["${SYM_UP_HALF}_up"]="█ ▄ "
    rules["${SYM_UP_HALF}_down"]="█ ▀ "

    rules["${SYM_DOWN_HALF}_left"]="$all"
    rules["${SYM_DOWN_HALF}_right"]="$all"
    rules["${SYM_DOWN_HALF}_up"]="█ ▄ "   # Restrict above ▄
    rules["${SYM_DOWN_HALF}_down"]="█ ▀ " # Re-added missing rule

    rules["${SYM_LEFT_HALF}_left"]="█ ▐ "
    rules["${SYM_LEFT_HALF}_right"]="$all"
    rules["${SYM_LEFT_HALF}_up"]="$all"    # Revert vertical rule for ▌
    rules["${SYM_LEFT_HALF}_down"]="$all"  # Revert vertical rule for ▌

    rules["${SYM_RIGHT_HALF}_right"]="█ ▌ "
    rules["${SYM_RIGHT_HALF}_left"]="$all"
    rules["${SYM_RIGHT_HALF}_up"]="$all"    # Revert vertical rule for ▐
    rules["${SYM_RIGHT_HALF}_down"]="$all"  # Revert vertical rule for ▐
  fi
}

# --- Constraint Filtering ---
filter_options() {
  local self_opts="$1"    # e.g., "▀▄█"
  local neighbor_allow="$2" # e.g., "█ ▄ "
  local new_opts=""        # Result: intersection
  local allowed_char

  # Iterate through each character allowed by the neighbor constraint
  while IFS= read -r -N1 allowed_char; do
    # Check if this allowed character ALSO exists in the original options
    if [[ "$self_opts" == *"$allowed_char"* ]]; then
      # If yes, add it to the new options string
      new_opts+="$allowed_char"
    fi
  done <<< "$neighbor_allow"

  # Ensure uniqueness and return string without newline
  echo -n "$new_opts" | grep -o . | sort -u | tr -d '\n'
}

# --- Grid Initialization ---
init_grid() {
  declare -gA grid possibilities collapsed cell_colors
  
  # Ensure rules are loaded!
  init_rules

  grid=(); possibilities=(); collapsed=(); cell_colors=()

  local all=""
  for s in "${SYMBOLS[@]}"; do all+="$s"; done
  all=$(echo "$all" | grep -o . | sort -u | tr -d '\n')

  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      local key="$y,$x"
      possibilities[$key]="$all"
      grid[$key]=" "
      collapsed[$key]=0
      cell_colors[$key]=""
    done
  done

  local sy=$((ROWS / 2)) sx=$((COLS / 2)) key="$sy,$sx"
  possibilities[$key]="█"
  collapsed[$key]=1
  grid[$key]="█"
  cell_colors[$key]=1
  propagate "$sy" "$sx"
}

# --- Propagation ---
propagate() {
  local y="$1" x="$2" start="$y,$x"
  [[ "${collapsed[$start]}" != "1" ]] && return
  local -a queue=("$start") # Initialize queue with the starting cell

  while ((${#queue[@]})); do
    local current="${queue[0]}"
    queue=("${queue[@]:1}")
    local cy="${current%,*}" cx="${current#*,}"
    local options="${possibilities[$current]}"
    [[ -z "$options" || "$options" == "$ERROR_SYMBOL" ]] && continue

    declare -A allowed
    for d in left right up down; do allowed[$d]="" ; done

    # Convert literal symbols read from possibilities string ($s) to symbolic names for rule lookup
    local s_char s_sym k
    while IFS= read -r -N1 s_char; do 
      [[ -z "$s_char" ]] && continue

      # Map literal char to symbolic name
      case "$s_char" in
          "▀") s_sym="SYM_UP_HALF" ;; 
          "▄") s_sym="SYM_DOWN_HALF" ;; 
          "▌") s_sym="SYM_LEFT_HALF" ;; 
          "▐") s_sym="SYM_RIGHT_HALF" ;; 
          "█") s_sym="SYM_FULL" ;; 
          " ") s_sym="SYM_SPACE" ;; 
          *)   
              log_warn "PROPAGATE: Unknown symbol '$s_char' found in possibilities. Skipping."
              continue 
              ;; # Unknown symbol
      esac

      [[ -z "$s_char" ]] && continue

      # Use symbolic name to look up rules
      k="${s_sym}_left";  allowed[left]+="${rules["$k"]-}"
      k="${s_sym}_right"; allowed[right]+="${rules["$k"]-}"
      k="${s_sym}_up";    allowed[up]+="${rules["$k"]-}"
      k="${s_sym}_down";  allowed[down]+="${rules["$k"]-}"
    done <<< "$options" # Read from the possibilities string

    for dir in left right up down; do
      local ny=$cy nx=$cx rev
      case "$dir" in
        left)  ((nx--)); rev=right ;;
        right) ((nx++)); rev=left ;;
        up)    ((ny--)); rev=down ;;
        down)  ((ny++)); rev=up ;;
      esac

      [[ $ny -lt 0 || $ny -ge $ROWS || $nx -lt 0 || $nx -ge $COLS ]] && continue
      local neighbor="$ny,$nx"
      [[ "${collapsed[$neighbor]}" == "1" ]] && continue

      local prev="${possibilities[$neighbor]}"
      local new
      new=$(filter_options "$prev" "${allowed[$dir]}")
      if [[ -z "$new" ]]; then
        # Contradiction: Mark neighbor as error and stop considering it
        STATUS_MESSAGE="Contradiction found at $neighbor involving $current. Marking error."
        log_event "PROPAGATE: Contradiction at $neighbor (from $current dir $dir). Marking ERROR." # Added logging
        grid[$neighbor]="$ERROR_SYMBOL"
        possibilities[$neighbor]="$ERROR_SYMBOL"
        collapsed[$neighbor]=1
        # Don't return, just don't add to queue and continue loop
      elif [[ "$new" != "$prev" ]]; then
        possibilities[$neighbor]="$new"
        # Only add to queue if it hasn't been collapsed (e.g. by an error)
        if [[ "${collapsed[$neighbor]}" != "1" && " ${queue[*]} " != *" $neighbor "* ]]; then
          queue+=("$neighbor")
        fi
      fi
    done
  done
  return 0 # Always return 0 now, errors handled by marking grid
}

# --- Collapse Step ---
update_algorithm() {
  local min=9999 keys=() all_done=1
  for k in "${!possibilities[@]}"; do
    [[ "${collapsed[$k]}" == "1" || "${possibilities[$k]}" == "$ERROR_SYMBOL" ]] && continue # Skip errors too
    all_done=0
    local opts="${possibilities[$k]}"
    local len
    len=$(echo -n "$opts" | wc -m) # Faster char count for multi-byte
    ((len < min)) && min=$len keys=("$k")
    ((len == min)) && keys+=("$k")
  done

  ((all_done)) && return 1
  (( ${#keys[@]} == 0 )) && return 1 # Should not happen if !all_done, but safe check

  local pick="${keys[RANDOM % ${#keys[@]}]}"
  local y="${pick%,*}" x="${pick#*,}" opts="${possibilities[$pick]}"

  # Check if the chosen cell is already an error (shouldn't happen with current logic, but safe)
  if [[ "$opts" == "$ERROR_SYMBOL" ]]; then
      STATUS_MESSAGE="Skipped already error cell $y,$x"
      return 0 
  fi

  local choice
  # Slightly faster random choice for multi-byte chars
  choice=$(echo -n "$opts" | fold -w1 | shuf -n1)

  grid[$pick]="$choice"
  possibilities[$pick]="$choice"
  collapsed[$pick]=1
  # Assign color based on chosen symbol (Mode 2 orientation)
  case "$choice" in
      "▀"|"▄"|"█") cell_colors[$pick]=1 ;; # Vertical color
      "▌"|"▐") cell_colors[$pick]=2 ;; # Horizontal color
      *) cell_colors[$pick]="" ;;      # Space/Other = default/no color
  esac

  propagate "$y" "$x" || return $?

  # Update status message
  STATUS_MESSAGE="Collapsed [$y,$x] (Entropy $min) to '$choice'"
  return 0 # Indicate successful step
}

# --- Engine Hook: Initialize Documentation ---
# Called by the engine to populate the documentation pages.
# PAGES array should already be defined globally.
init_docs() {
    # PAGES is already defined at the top of this script.
    # No specific initialization needed here for this algo.
    : # No-op
}

# --- Engine Hook: Get Current Mode Name ---
# Called by the rendering engine to get a friendly name for the current mode.
get_current_mode_name() {
    local mode_index=${BLOCKY_RULE_MODE:-0} # Use global variable
    echo "${BLOCKY_MODE_NAMES[$mode_index]:-Unknown}" # Return name or fallback
}

# --- Engine Hook: Get Semantic State ---
# Called by the engine's renderer to get the state for a cell.
# Returns a string representing the state (e.g., 'BLOCK_FULL', 'EMPTY', etc.)
# This algo uses the character in the grid directly as its state.
get_state() {
    local r=$1
    local c=$2
    local key="$r,$c"
    local char="${grid[$key]:- }"
    local color_id="${cell_colors[$key]}"
    local color_name=""

    case "$color_id" in
        1) color_name="BLOCKY_FG_1" ;;
        2) color_name="BLOCKY_FG_2" ;;
    esac

    if [[ -n "$color_name" ]]; then
        echo "$char|$color_name"
    else
        echo "$char"
    fi
}
