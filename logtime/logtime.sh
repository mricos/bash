#!/bin/bash
LT_MAX_MARKS=32000
LT_DIR=~/.logtime
LT_STATES=$LT_DIR/states
LT_COMMITS=$LT_DIR/commits
LT_SRC="$(dirname "$BASH_SOURCE")"
source "$LT_SRC/help.sh"
source "$LT_SRC/helpers.sh"
source "$LT_SRC/aliases.sh"
source "$LT_SRC/date.sh"
source "$LT_SRC/prompt.sh"
source "$LT_SRC/store.sh"
#source "$LT_SRC/clipboard.sh"
#source "$LT_SRC/stack.sh"
source "$LT_SRC/development.sh"

logtime-load(){
  if [[ $# -eq  0 ]]; then
    _logtime-load-interactive states
  else
    _logtime-source "$1"
  fi
  logtime-prompt   # changes PS1 to show elapsed time
}

logtime-load-commit(){
  if [[ $# -eq  0 ]]; then
    _logtime-load-interactive commits
  else
    _logtime-source "$1"
  fi
  logtime-prompt  # changes PS1 to show elapsed time
}


logtime-start() {
  local when="now"
  local msg

  if [ -n "$LT_START" ]; then
    echo "LT_START not empty. Use _logtime-clear to clear."
    return -1
  fi

  if [ -n "$1" ] && date -d "$1" &>/dev/null; then
    when="$1"
    msg="${@:2}"
  elif [ -n "$1" ] && date -d "-@$1" &>/dev/null; then
    when="$(date -d "-@$1")"
    msg="${@:2}"
  else
    msg="$*"
  fi

  echo "When is $when and msg is $LT_MSG"

  LT_START=$(date +%s -d "$when")
  LT_LASTMARK=$LT_START
  LT_STOP=""
  LT_MSG="$msg"

  _logtime-save
  _logtime-start-text
}

logtime-restart(){
    local lt_start_old=$LT_START
    LT_START=$(date +%s -d "$1" )
    LT_LASTMARK=$LT_START
    LT_STOP=""
    LT_MSG="$msg"
}

# Marks define a length of time if no length is given in hms, then:
# markdur = curtime-LT_START-markdur_total
#
# 1700546780 Starting to do something
# 363 This is the first mark for 0h6m3s
# 3600 This is second mark string   for 1h
# 1800 This thrid task lasted 0h30m0s
# 9003 marktime_total

logtime-mark() {
  [ ! -z "$LT_STOP" ] && echo "protected" && return
  local curtime=$(date +%s)
  dur=0
  dur=$(_logtime-hms-to-seconds  $1)
  if [ "$dur" -eq 0 ]                   # 0 if not an hms string
  then
    dur=$(( $curtime - $LT_LASTMARK ))
    local msg="${@:1}"
  else
    local msg="${@:2}"
  fi

  # If the user adds a duration and it is less than
  # (curtime - LT_LASTMARK) then add the user's duration
  # to LASTMARK. Otherwise LASTMARK=currentTime.

  # Rather than conditional else, do it in two lines like this:
  local lastmark=$LT_LASTMARK
  (( dur < curtime - lastmark )) &&  LT_LASTMARK=$((LT_LASTMARK + dur));
  (( dur >= curtime - lastmark )) && LT_LASTMARK=$curtime;
  IFS_ORIG=$IFS
  IFS=$'\n'
  LT_MARKS+=("$dur $msg")              # array created on newline boundaries
  IFS=$IFS_ORIG
  _logtime-save
}

logtime-mark-undo(){
  local mark=("${LT_MARKS[-1]}")           # last element
  IFS=' ' read first rest <<< "$mark"
  LT_LASTMARK=$(($LT_LASTMARK - $first ))  # roll back when last mark was made
  unset 'LT_MARKS[-1]'                       # leaves a blank line
}

logtime-rebase(){
  local total=0
  LT_LASTMARK=$LT_START
  for line in "${LT_MARKS[@]}"; do
    dur="${line%% *}"                 # substring removal
    echo "$dur $line"                 # first token is duration in seconds
    ((total+=$dur))
  done
  (( LT_LASTMARK = LT_START + total ))
  printf "        Total seconds:%s (%2.2f days)\n" \
      $total $(jq -n "$total/(60*60*24)") > /dev/stderr
  printf "LT_LASTMARK-LT_START: %s (%2.2f days)\n" \
      $((LT_LASTMARK-LT_START)) $(jq -n "$total/(60*60*24)")  > /dev/stderr
}

logtime-states(){
  _logtime-objects "$LT_STATES"
  lts=()
  for file in $(ls "$LT_DIR/states")
  do
      lts+=("$LT_DIR/states/$file")
  done
}

logtime-commits(){
   local lt_msg="$LT_MSG"
  _logtime-objects marks"$LT_DIR/commits"     # displays them
  ltc=()
  for file in $(ls "$LT_DIR/commits")    # create array of them
  do
      ltc+=("$LT_DIR/commits/$file")
  done

  LT_MSG="$lt_msg"
}

logtime-commit(){

  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
    return -1
  fi

  if [ -z $1 ]
  then
    commitmsg="Committed $LT_MSG"
  else
    local commitmsg="${@:1}"
  fi

  LT_COMMIT="$commitmsg"

  local totalMarks=0
  local calcStop=0
  local now=$(date +%s)
  local stoppedSecondsAgo=0
  ((totalMarks = LT_LASTMARK-LT_START))
  ((calcStop = LT_START+totalMarks))
  (( secAgo= now-calcStop))
  local hmsAgo=$(_logtime-hms $secAgo)
  echo "Total marks:"  $(jq -n "$totalMarks/(60*60*24)") $hmsAgo ago.
  echo "Calc stop:"  $(date --date=@$calcStop)
  LT_STOP=$calcStop
  _logtime-stop # will not return if stop has not been called
  local datestart=$(date --date=@$LT_START)
  local datestop=$(date --date=@$LT_STOP)
  local deltaSeconds=$(($LT_STOP - $LT_START))
  local remaining=$(($LT_STOP - $(date +%s) ))
  local duration=$(_logtime-hms $deltaSeconds )
  printf 'logtime-marks: \n'
  logtime-marks
  printf '%s\n' "Message: $LT_MSG"
  printf 'Date start: %s\n'  "$datestart"
  printf 'Date stop: %s\n'  "$datestop"
  printf '%s %s\n' "Open duration:" $duration
  commitmsg="$commitmsg at $datestop"
  printf '%s\n' "Commit msg: $commitmsg"
  printf '%s\n' "logtime-start $datestop)"
  printf 'Commit? ctrl-c to cancel, return to continue\n'
  read ynCommit
  _logtime-save
  mv "$LT_STATES/$LT_START" "$LT_COMMITS/$LT_START"
  rm "$LT_STATES/$LT_START.*" 2> /dev/null # may not be any dot ext
  echo "moved $LT_STATES/$LT_START $LT_COMMITS/$LT_START"
  _LT_LAST_START=$LT_START
  _logtime-clear
}

logtime-commit-undo(){
  local file="$LT_DIR/commits/$LT_START"
  echo $file
  logtime-load $file
  LT_STOP=""
  LT_COMMIT=""
  echo "Be sure to logtime-save"
}

logtime-status(){
  if [ -z "$LT_START" ]; then
    echo "
   No timer started.
   Use logtime-start <optional message of intention>
"
    return 1
  fi

  local ts=$(date +%s)
  local elapsed=$((ts - LT_START))
  local dur=$(($LT_STOP - LT_START))
  local elapsedHms=$(_logtime-hms $elapsed)
  local datestr=$(date --date="@$LT_START")
  echo
  echo "  LT_START=$LT_START ($datestr, elapsed:$elapsedHms)"
  echo "  LT_MSG=$LT_MSG"
  echo "  LT_STOP=$LT_STOP ($datestr, duration: $dur)"
  echo "  Run logtime-marks to see marks for current sequence"
  echo
}

logtime-marks(){
  IFS_ORIG=$IFS
  IFS=$"\n"
  local total=0
  local abstime=0
  local n=0
  local start=${1:-0}
  local end=${2:-${#LT_MARKS[@]}}
  _logtime-meta-restore
  lt_clipboard=()
  for line in "${LT_MARKS[@]}"; do
    IFS=' ' read left right <<< "$line"
    local hms=$(_logtime-hms $left)
    (( abstime=(LT_START + total) ))
    if (( $n >=  "$start"  && $n <= "$end" )); then
      printf "%3s %5s %-36s  %9s %3s" \
          $n $left "$right" $hms "${marks_disposition[$n]}"
      printf " %s\n" "$(date +"%a %D %H:%M" -d@$abstime )"
      lt_clipboard+=("$line")
    fi
    (( total+=$left ))
    (( n++ ))
  done;
  (( abstime=(LT_START + total) ))
  printf "%59s %20s \n" " " "$( date +"%a %D %H:%M" -d@$abstime )"
  IFS=$IFS_ORIG
  printf "        Total seconds:%s (%2.2f days)\n" \
      $total $(jq -n "$total/(60*60*24)")
  printf "LT_LASTMARK-LT_START: %s (%2.2f days)\n" \
      $((LT_LASTMARK-LT_START)) $(jq -n "$total/(60*60*24)")
}

logtime-marks-reload(){
  [ -f $LT_DIR/states/$LT_START ] && \
    echo logtime-load $LT_DIR/states/$LT_START
  [ ! -f $LT_DIR/states/$LT_START ] && \
    echo NOT FOUND:  $LT_DIR/states/$LT_START
}

logtime-summary(){
  local filter=${1:-"1"} # do nothing, all files have a 1 in them!
  local totalsec="$( logtime-marks  | \
      grep $filter    | \
      awk '{s+=$2} END {print s}' \
  )"
    echo $(( totalsec / 3600 )) hours for $filter
}
