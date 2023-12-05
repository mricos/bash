_logtime-clipboard-write(){
  declare -xp lt_clipboard > $LT_DIR/clipboard
}

_logtime-clipboard-read(){
  source $LT_DIR/clipboard
}

_logtime-clipboard-stdin() {
    lt_clipboard=() # Initialize an empty array
    while IFS= read -r line; do
        lt_clipboard+=("$line")
    done
}

logtime-marks-copy(){
  _logtime-clipboard-stdin
  declare -xp lt_clipboard > $LT_DIR/clipboard
}


logtime-marks-paste(){
  # The syntax/semantic contract requires clipboard contain a single varialbe
  # and it is wiped every copy. Single source of truth is the disk.
  source $LT_DIR/clipboard
  for line in "${lt_clipboard[@]}"; do
    echo "$line"
  done
}

_logtime-marks-insert-from-clipboard(){
    local marks=("${LT_MARKS[@]}")

    local pos=${2:-${#marks[@]}}

    for line in "${lt_clipboard[@]}"; do
        marks=("${marks[@]:0:$pos}" "$line" "${marks[@]:$pos}")
        ((pos++))
    done

    LT_MARKS=("${marks[@]}")
}


logtime-marks-cut() {
    local start=$(( $1 -1  ))
    local end=$(( $2 - 1 ))
    lt_cut=("${LT_MARKS[@]:$start:$((end-start+1))}")

    # Create a new array from the elements before start and the elements after end
    LT_MARKS=("${LT_MARKS[@]:0:$((start+1))}" \
              "${LT_MARKS[@]:$((end+1)):${#LT_MARKS[@]}}")

    lt_clipboard=();
    for i in "${lt_cut[@]}"; do lt_clipboard+=("$i"); done
    _logtime-clipboard-write
}

# To use:
#   _logtime-marks-insert-from-stdin < <(paste)
_logtime-marks-insert-from-stdin() {
    # Create a copy of the array
    local marks=("${LT_MARKS[@]}")
    local insert_lines=()

    # Read from stdin and store in an array
    while IFS= read -r line; do
        insert_lines+=("$line")
    done

    local pos=${1:-${#marks[@]}}

    # Insert the lines at the specified position and update the array
    LT_MARKS=("${marks[@]:0:$pos}" "${insert_lines[@]}" "${marks[@]:$pos}")
}
