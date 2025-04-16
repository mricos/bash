#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# --- WFC: Blocky ASCII Shapes Generator ---
# Generates visual grid patterns using block characters and WFC logic.

# --- Configuration ---
export SYMBOLS=( "▀" "▄" "▌" "▐" "█" " " )
export ERROR_SYMBOL="X"
export ALGO_TILE_WIDTH=1
export ALGO_TILE_HEIGHT=1

# --- Documentation Pages ---
export PAGES=(
  "BLOCKY SHAPES
Uses block characters (▀ ▄ ▌ ▐ █) and space.
The Wave Function Collapse (WFC) algorithm
generates structured grid patterns by applying
connection constraints and propagating limits."

  "HOW IT WORKS
1. Each cell begins with all symbols available.
2. Rules determine symbol adjacency compatibility.
3. Minimum entropy heuristic selects a cell to collapse.
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
)

# --- Rule Definitions ---
init_rules() {
  declare -gA rules
  rules=()
  local all="▀ ▄ ▌ ▐ █ "

  for dir in left right up down; do
    rules["█_$dir"]="$all"
    rules[" _$dir"]="$all"
  done

  rules["▀_left"]="$all"
  rules["▀_right"]="$all"
  rules["▀_up"]="█ ▄ "
  rules["▀_down"]="$all"

  rules["▄_left"]="$all"
  rules["▄_right"]="$all"
  rules["▄_up"]="$all"
  rules["▄_down"]="█ ▀ "

  rules["▌_left"]="█ ▐ "
  rules["▌_right"]="$all"
  rules["▌_up"]="$all"
  rules["▌_down"]="$all"

  rules["▐_right"]="█ ▌ "
  rules["▐_left"]="$all"
  rules["▐_up"]="$all"
  rules["▐_down"]="$all"
}

# --- Constraint Filtering ---
filter_options() {
  local self_opts="$1" neighbor_allow="$2" out=""
  while IFS= read -r -n1 c; do
    [[ "$neighbor_allow" == *"$c"* ]] && out+="$c"
  done <<< "$self_opts"
  echo "$out" | grep -o . | sort -u | tr -d '\n'
}

# --- Grid Initialization ---
init_grid() {
  declare -gA grid possibilities collapsed cell_colors
  grid=(); possibilities=(); collapsed=(); cell_colors=()

  local all=""
  for s in "${SYMBOLS[@]}"; do all+="$s"; done
  all=$(echo "$all" | grep -o . | sort -u | tr -d '\n')

  export ROWS=20
  export COLS=40

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
  local -a queue=("$start")
  local -A seen; seen["$start"]=1

  while ((${#queue[@]})); do
    local current="${queue[0]}"
    queue=("${queue[@]:1}")
    local cy="${current%,*}" cx="${current#*,}"
    local options="${possibilities[$current]}"
    [[ -z "$options" || "$options" == "$ERROR_SYMBOL" ]] && continue

    declare -A allowed
    for d in left right up down; do allowed[$d]="" ; done

    while IFS= read -r -n1 s; do
      [[ -z "$s" ]] && continue
      local k
      k="${s}_left";  allowed[left]+="${rules["$k"]-}"
      k="${s}_right"; allowed[right]+="${rules["$k"]-}"
      k="${s}_up";    allowed[up]+="${rules["$k"]-}"
      k="${s}_down";  allowed[down]+="${rules["$k"]-}"
    done <<< "$options"

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
        STATUS_MESSAGE="Backtracking due to contradiction at $neighbor"
        return 2
      elif [[ "$new" != "$prev" ]]; then
        possibilities[$neighbor]="$new"
        queue+=("$neighbor")
      fi
    done
  done
}

# --- Collapse Step ---
update_algorithm() {
  local min=9999 keys=() all_done=1
  for k in "${!possibilities[@]}"; do
    [[ "${collapsed[$k]}" == "1" ]] && continue
    all_done=0
    local opts="${possibilities[$k]}"
    local len
    len=$(echo "$opts" | grep -o . | wc -l)
    ((len < min)) && min=$len keys=("$k")
    ((len == min)) && keys+=("$k")
  done

  ((all_done)) && return 1
  (( ${#keys[@]} == 0 )) && return 1

  local pick="${keys[RANDOM % ${#keys[@]}]}"
  local y="${pick%,*}" x="${pick#*,}" opts="${possibilities[$pick]}"
  local choice
  choice=$(echo "$opts" | grep -o . | shuf -n1)

  grid[$pick]="$choice"
  possibilities[$pick]="$choice"
  collapsed[$pick]=1
  ((RANDOM % 2 == 0)) && cell_colors[$pick]=1 || cell_colors[$pick]=2

  propagate "$y" "$x" || return $?
  return 0
}

# --- Draw Grid ---
draw_grid() {
  for ((y=0; y<ROWS; y++)); do
    for ((x=0; x<COLS; x++)); do
      key="$y,$x" char="${grid[$key]}" clr="${cell_colors[$key]}"
      if [[ "$clr" == "1" ]]; then
        echo -ne "\033[47;44m$char\033[0m"
      elif [[ "$clr" == "2" ]]; then
        echo -ne "\033[47;46m$char\033[0m"
      else
        echo -n "$char"
      fi
    done
    echo
  done
}

# --- Main Loop ---
main() {
  export LOG_FILE="/tmp/blocky_wfc.log"
  > "$LOG_FILE"
  STATUS_MESSAGE=""
  init_rules
  init_grid
  declare -a snapshots=()

  while :; do
    snapshots+=("$(declare -p grid possibilities collapsed cell_colors)")
    update_algorithm
    rc=$?
    clear
    draw_grid
    echo -e "\n$STATUS_MESSAGE"
    if (( rc == 1 )); then
      echo -e "\nDone."
      break
    elif (( rc == 2 )); then
      snapshot="${snapshots[-2]}"
      unset 'snapshots[-1]'
      eval "$snapshot"
      STATUS_MESSAGE="Rolled back due to conflict..."
    else
      sleep 0.05
    fi
  done
}
