#!/bin/bash
TIMELOG=~/time.txt

#LT_STATE_DIR=${LT_STATE_DIR:="/home/mricos/.timecard/commits"}
LT_STATE_DIR=${LT_STATE_DIR:="./state"}
LT_COMMIT_DIR=${LT_COMMIT_DIR:="./commit"}

# date +%s <-- create UNIX epoch time stamp in seconds
# date --date=@$TS  <-- create datetime string from TS env var

logtime-clear(){
  LT_START=""
  LT_START_MSG=""
  LT_ARRAY=()
}

logtime-commit(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local outfile="$LT_COMMIT_DIR/$LT_START"
    declare -p ${!LT_@} > "$outfile"
    logtime-status >> $TIMELOG
  fi
}

logtime-restore(){
    source $1
}

logtime-is-date(){
  date -d "$1" 2>: 1>:; echo $? # returns 0 if true, 1 if error
}

logtime-str2time(){
  date +%s -d "$1"
}

logtime-start() {
  if [ ! -z $LT_START ]; then
    echo "LT_START not empty. Use logtime-clear to clear."
    return -1
  else
    if date -d "$1" 2>: 1>:; then  # test, send stdio to /dev/null
      local when=$1;
      local msg=${@:2};
    else
      local when="now";
      local msg=${@:1};
    fi

    LT_START=$(date +%s -d $when)
    LT_START_MSG=$msg
    echo "$LT_START $LT_START_MSG"
    return 0 
    IFS_ORIG=$IFS
    IFS=$'\n'  
    LT_ARRAY=($(logtime-string $LT_START  0  $@))
    IFS=$IFS_ORIG
  fi
}

logtime-mark() {
  IFS_ORIG=$IFS
  local timemark=$(date +%s)
  IFS=. read left right <<< ${LT_ARRAY[-1]}
  local lastmark=$left
  local dur=$((timemark - lastmark ))
  IFS=$'\n'  
  LT_ARRAY+=($(logtime-string $timemark  $dur $@))
  IFS=$IFS_ORIG
}

logtime-stop() {
  LT_STOP=$(date +%s)
  LT_DURATION=$((LT_STOP - LT_START))
}

logtime-string() {
  echo "$1.$2.\""${@:3}"\""
}

logtime-hms(){
  local h=$(($1 / 3600));
  local m=$((($1 % 3600) / 60));
  local s=$(($1 % 60));
  echo "${h}h${m}m${s}s";
}

logtime-hms-to-seconds(){
  seconds=$(echo $1 | awk -F'[hmd:]' \
    '{ print ($1 * 3600) + ($2 * 60) + $3 }')
 echo $seconds
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
  local elapsedHms=$(logtime-hms $elapsed)
  echo "LT_START: $LT_START ($elapsedHms)"
  echo "LT_START_MSG: $LT_START_MSG"
  echo "TIMELOG: $TIMELOG"
  echo "LT_ARRAY:"
  printf '%s \n' ${LT_ARRAY[@]}
  IFS_ORIG=$IFS
  IFS="" 
  for line in ${LT_ARRAY[@]}; do
     IFS=. read left right <<< "$line"
     deltatime=$(( left - $LT_START ))
     deltatime=$(logtime-hms $deltatime)
    printf "%s %s (%s)\n" $left $right $deltatime
  done; 
  IFS=$IFS_ORIG
  echo ""
}

logtime-commit-old() {
  LT_STOP=$(date +%s)
  local str=$@
  if [ -n "$str" ]; then
     LT_STOP_MSG=$str
  fi

  echo "start.$LT_START.\"$LT_START_MSG\""
  if [ -n "$LT_ARRAY" ]; then
    printf "mark.%s\n" "${LT_ARRAY[@]}"
  fi
  echo "stop.$LT_STOP.\"$LT_STOP_MSG\".$LT_DURATION"
}

# Porcelain
alias ltls="cat $TIMELOG"

# Development
logtime-dev-parse() {
  while IFS= read -r line; do  #get the whole line, no IFS
      IFS=.; tokens=($line)    # now IFS is .
      local tsHuman=$(date -d@${tokens[0]} 2> /dev/null) 
      if [ ! -z "$tsHuman" ]
      then
        printf '%s\n' "$tsHuman"
        printf '%s\n\n' ${tokens[1]} 
      fi
      IFS=$' \t\n'
  done < "$TIMELOG" 
  IFS=$' \t\n'
}
