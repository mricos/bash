#!/usr/bin/env bash
# -- WFC Algorithm: Evolving 2x2 Braille Seed --

# Define initial seed (2x2 fully-filled braille: ⣿)
SEED_TL="⣿"
SEED_TR="⣿"
SEED_BL="⣿"
SEED_BR="⣿"

# Symbols used by the algorithm
export SYMBOLS=(
  "⠀" "⠉" "⠤" "⣀" "⡇" "⢸" "⠿" "⣶" "⣤" "⣿"
)

# Use ? for error states
ERROR_SYMBOL="?"

# Documentation Pages
export PAGES=(
  "EVOLVING 2x2 BRAILLE SEED Starts with a 2x2 Braille block (⣿⣿ / ⣿⣿) in the center and evolves outwards using WFC with Braille compatibility rules."
  "HOW IT WORKS 1. init_grid places the 2x2 seed. 2. propagate updates neighbors. 3. update_algorithm finds the cell with Minimum Entropy (fewest valid options) and collapses it. 4. Repeats step 3, growing from the initial seed based on rules."
  "BRAILLE RULES Neighboring Braille patterns must have matching dots along their shared edge to be valid. This ensures visual continuity as the pattern evolves."
  "SYMBOLS USED Seed: ⣿⣿ / ⣿⣿ Full Set: ${SYMBOLS[*]}"
)

# Logging
LOG_FILE="/tmp/braille_wfc.log"
> "$LOG_FILE"

# Associative map: Braille character → bit pattern
declare -gA BRAILLE_PATTERNS=(
  ["⠀"]=0x00 ["⠉"]=0x09 ["⠤"]=0x24 ["⣀"]=0x06 ["⡇"]=0x87
  ["⢸"]=0xE0 ["⠿"]=0x3F ["⣶"]=0xE3 ["⣤"]=0x6C ["⣿"]=0xFF
)

# Braille char → 8-bit binary string
declare -gA BRAILLE_DOTS

# Converts BRAILLE_PATTERNS to binary dot presence
_init_braille_dots() {
  BRAILLE_DOTS=()
  for ch in "${!BRAILLE_PATTERNS[@]}"; do
    bits=${BRAILLE_PATTERNS[$ch]}
    bin=""
    for (( i = 7; i >= 0; i-- )); do
      (( (bits >> i) & 1 )) && bin+="1" || bin+="0"
    done
    BRAILLE_DOTS["$ch"]="$bin"
  done
}

# Check if two characters are compatible across `dir` edge
check_braille_compatibility() {
  local a="$1" b="$2" dir="$3"
  local pa="${BRAILLE_DOTS[$a]}" pb="${BRAILLE_DOTS[$b]}"
  [[ -z "$pa" || -z "$pb" ]] && return 1

  case "$dir" in
    left)
      [[ "${pa:0:3}" == "${pb:3:3}" && "${pa:6:1}" == "${pb:7:1}" ]]
      ;;
    right)
      [[ "${pa:3:3}" == "${pb:0:3}" && "${pa:7:1}" == "${pb:6:1}" ]]
      ;;
    up)
      [[ "${pa:0:1}" == "${pb:2:1}" &&
         "${pa:1:1}" == "${pb:5:1}" &&
         "${pa:3:1}" == "${pb:6:1}" &&
         "${pa:4:1}" == "${pb:7:1}" ]]
      ;;
    down)
      [[ "${pa:2:1}" == "${pb:0:1}" &&
         "${pa:5:1}" == "${pb:1:1}" &&
         "${pa:6:1}" == "${pb:3:1}" &&
         "${pa:7:1}" == "${pb:4:1}" ]]
      ;;
    *) return 1 ;;
  esac
}

# Global rules = direction-based compatibility per symbol
declare -gA rules

init_rules() {
  _init_braille_dots
  echo "Initializing compatibility rules..." >> "$LOG_FILE"
  for sym1 in "${SYMBOLS[@]}"; do
    for dir in left right up down; do
      allowed=""
      for sym2 in "${SYMBOLS[@]}"; do
        if check_braille_compatibility "$sym1" "$sym2" "$dir"; then
          allowed+="$sym2 "
        fi
      done
      rules["${sym1}_${dir}"]="${allowed% }"
    done
  done
  echo "Rules initialized" >> "$LOG_FILE"
}

# Grid data structures
declare -gA grid possibilities collapsed

# Filter possibilities based on allowed values
filter_options() {
  local current_str="$1" allowed_str="$2"
  local -a current=($current_str)
  local result=()
  for c in "${current[@]}"; do
    [[ " $allowed_str " =~ " $c " ]] && result+=("$c")
  done
  echo "${result[*]}"
}

# Propagation logic
propagate() {
  local y="$1" x="$2"
  local -a queue=("$y,$x")
  local -A seen=()

  seen["$y,$x"]=1
  while [[ ${#queue[@]} -gt 0 ]]; do
    local key="${queue[0]}"
    queue=("${queue[@]:1}")
    local cy=${key%,*} cx=${key#*,}

    [[ ${grid[$key]} == "$ERROR_SYMBOL" ]] && continue

    for dir in left right up down; do
      local ny=$cy nx=$cx opp_dir current_opts rule_key allowed union neighbor_key new_opts
      case $dir in
        left)  nx=$((cx - 1)); ny=$cy; opp_dir=right ;;
        right) nx=$((cx + 1)); ny=$cy; opp_dir=left ;;
        up)    ny=$((cy - 1)); nx=$cx; opp_dir=down ;;
        down)  ny=$((cy + 1)); nx=$cx; opp_dir=up ;;
      esac

      [[ $ny -lt 0 || $ny -ge $ROWS || $nx -lt 0 || $nx -ge $COLS ]] && continue

      neighbor_key="$ny,$nx"
      [[ "${collapsed[$neighbor_key]}" == "1" ]] && continue

      allowed=""
      for opt in ${possibilities[$key]}; do
        rule_key="${opt}_$dir"
        allowed+=" ${rules[$rule_key]}"
      done
      allowed=$(echo "$allowed" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

      [[ -z "$allowed" ]] && continue

      new_opts=$(filter_options "${possibilities[$neighbor_key]}" "$allowed")

      if [[ "$new_opts" != "${possibilities[$neighbor_key]}" ]]; then
        possibilities[$neighbor_key]="$new_opts"
        grid[$neighbor_key]="$new_opts"
        if [[ -z "$new_opts" ]]; then
          grid[$neighbor_key]="$ERROR_SYMBOL"
          collapsed[$neighbor_key]=1
        elif [[ -z "${seen[$neighbor_key]}" ]]; then
          queue+=("$neighbor_key")
          seen[$neighbor_key]=1
        fi
      fi
    done
  done
}

# Initialize grid with 2x2 seed in center
init_grid() {
  grid=(); possibilities=(); collapsed=()
  local symbols="${SYMBOLS[*]}"

  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      key="$y,$x"
      grid[$key]="$symbols"
      possibilities[$key]="$symbols"
      collapsed[$key]=0
    done
  done

  local cy=$(( (ROWS - 1) / 2 ))
  local cx=$(( (COLS - 1) / 2 ))
  local keys=( "$cy,$cx" "$cy,$((cx+1))" "$((cy+1)),$cx" "$((cy+1)),$((cx+1))" )
  local values=( "$SEED_TL" "$SEED_TR" "$SEED_BL" "$SEED_BR" )

  for i in ${!keys[@]}; do
    grid[${keys[i]}]="${values[i]}"
    possibilities[${keys[i]}]="${values[i]}"
    collapsed[${keys[i]}]=1
    propagate "${keys[i]%,*}" "${keys[i]#*,}"
  done

  STATUS_MESSAGE="Evolving 2x2 Grid Initialized"
}

# Main WFC logic — collapse min entropy cell
update_algorithm() {
  local min=9999 key entropy collapsed_count=0
  local -a candidates=()
  for key in "${!possibilities[@]}"; do
    [[ "${collapsed[$key]}" == "1" ]] && continue
    local opts=( ${possibilities[$key]} )
    entropy=${#opts[@]}
    (( entropy == 0 )) && {
      grid[$key]="$ERROR_SYMBOL"
      collapsed[$key]=1
      continue
    }

    (( entropy < min )) && {
      min=$entropy
      candidates=( "$key" )
    } || (( entropy == min )) && candidates+=( "$key" )
  done

  [[ ${#candidates[@]} -eq 0 ]] && { STATUS_MESSAGE="Evolving Error: No candidates"; return 1; }

  local chosen="${candidates[RANDOM % ${#candidates[@]}]}"
  local options=( ${possibilities[$chosen]} )
  local symbol="${options[RANDOM % ${#options[@]}]}"
  grid[$chosen]="$symbol"
  possibilities[$chosen]="$symbol"
  collapsed[$chosen]=1

  propagate "${chosen%,*}" "${chosen#*,}"
  for k in "${!collapsed[@]}"; do [[ "${collapsed[$k]}" == "1" ]] && ((collapsed_count++)); done
  STATUS_MESSAGE="Collapsed $chosen -> '$symbol' | $collapsed_count / $((ROWS * COLS))"
  return 0
}

