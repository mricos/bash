LT_STACK=()
logtime-stack-push-hms(){
  local dur=$(_logtime-hms-to-seconds  $1)
  local msg="${@:2}"
  LT_STACK+=("$dur $msg")
}

logtime-stack-pop(){
  local N=${1:-1}                  # default N=1, pop and echo N elements
  local n=0
  source $LT_DIR/stack             #ssot-write: single source of truth

  while (( n < N )) ; do
    (( n++ )) 
    [ ! -z "$LT_STACK" ] \
        && echo "${LT_STACK[-1]}" \
        2> /dev/null;
    [ ! -z "$LT_STACK" ] \
        && unset LT_STACK[-1] 2> /dev/null;
  done

  declare -xp  LT_STACK  > \
      $LT_DIR/stack                #ssot-read:stack 

  [ -z "$LT_STACK" ] \
      && { echo "empty stack"; return -1; }
}

# Push to the one and only stack. Each operation writes
# to disk so that the stack is shared globally. #sharptool
logtime-stack-push(){
  local msg="${@}"                 # assume arguments are a string to push
  local src="/dev/stdin"           # is set to null if args are passed
  source $LT_DIR/stack             # Single source of truth is disk

  if [ ! -z "$msg" ]               # if not unset or empty string 
  then                             # then we we will all command line string
    LT_STACK+=("$msg");
    declare -xp  LT_STACK  > \
                 $LT_DIR/stack     # write sigle source of truth
    src=/dev/null                  # this will short circuit read on stdin
    return 0
  else                             # else push lines from stdin
    while read line                # read parses on \n comming from < $src
    do
      LT_STACK+=( "$line" );
      printf "pushed: %s\n" "$line"
    done < "$src"
  
    #export LT_STACK
    declare -xp  LT_STACK  > $LT_DIR/stack
  fi
}

logtime-stack-clear(){
  unset LT_STACK
  cat /dev/null > $LT_DIR/stack
}

logtime-stack-peek(){
  source $LT_DIR/stack
  for line in "${LT_STACK[@]}"; do
    echo "$line"
  done
}

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
