#!/bin/bash
#LT_DIR=~/src/mricos/bash/logtime
LT_DIR=~/.logtime
LT_STATE_DIR=$LT_DIR/state
LT_COMMIT_DIR=$LT_DIR/commits

_logtime-webserver() {
  while true; do  
    echo -e "HTTP/1.1 200 OK\r\n$(date)\r\n\r\n$(cat $1)" | nc -vl 0.0.0.0:8080; 
  done
}

_logtime-clear(){
  LT_START=""
  LT_START_MSG=""
  LT_MARK_TOTAL=0
  LT_LASTMARK=0
  LT_ARRAY=()
}

_logtime-save(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local outfile=$LT_STATE_DIR/$LT_START
    export ${!LT_@}
    declare -ap  ${!LT_@}  > "$outfile"
    if [ $? -eq 0 ]; then
      printf '%s\n' "Wrote to $outfile"
    fi
  fi
}

_logtime-select-state() {
  dir=$LT_STATE_DIR
  echo "Select from: $dir" 
  local filenames=""
  local listing=$(ls -1 "$dir")
  readarray -t filenames <<< "$listing";
  for i in "${!filenames[@]}"  #0 indexing ${!varname[@]} returns indices
  do
    local msg=$(source "$dir/${filenames[$i]}"; echo "$LT_START_MSG")  
    echo "$((i+1)))  ${filenames[$i]}: $msg"
  done

  read filenum 
  filenum=$((filenum-1))
  state="$dir/${filenames[$filenum]}"
  _logtime-source $state
}


_logtime-source(){

  while read -r line
  do
    if [[ $line == declare\ * ]]
    then
        tokens=($(echo $line))  # () creates array
        # override flags with -ag global since declare does not provide g
        local cmd="${tokens[0]} -ag ${tokens[@]:2}" 
        echo $cmd
        eval  "$cmd"
    fi
  done < "$1"

  export ${!LT_@}
}

logtime-info(){
    declare -p  ${!LT_@} 
}

logtime-load(){
  _logtime-select-state
  _logtime-prompt
}

logtime-commit(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
    return -1
  fi 
  
  if [ -z $LT_STOP ]; then
    echo "LT_STOP is empty. Use _logtime-stop [offset] [message]."
    return -1
  fi 

  if [ -z $1 ] # if there is one or more arguments, treat it as string
     then
        local commitmsg=$LT_STOP_MSG
      else
        local commitmsg="${@:1}"
  fi 

  _logtime-stop # will not return if stop has not been called 
  local datestart=$(date --date=@$LT_START)
  local datestop=$(date --date=@$LT_STOP)
  local duration=$(_logtime-hms $LT_DURATION)
  printf 'logtime-marks: \n'
  logtime-marks
  printf 'Date start: %s\n'  "$datestart" 
  printf 'Date stop: %s\n'  "$datestop" 
  printf '%s\n' "Start: $LT_START_MSG"
  printf '%s %s\n' "Duration:" $duration
  printf '%s\n' "Stop: $LT_STOP_MSG"
  printf '%s\n' "Commit msg: $commitmsg"
  printf 'Commit? ctrl-c to cancel, return to continue\n'
  read ynCommit

  _logtime-save
  mv "$LT_STATE_DIR/$LT_START" "$LT_COMMIT_DIR/$LT_START"
  echo "moved $LT_STATE_DIR/$LT_START $LT_COMMIT_DIR/$LT_START"
  _logtime-clear
}

logtime-start() {
  if [ ! -z $LT_START ]; then
    echo "LT_START not empty. Use _logtime-clear to clear."
    return -1
  else
    if date -d "$1" &>/dev/null; then  # test, send stdio to /dev/null
      local when=$1;
      local msg="${@:2}";
    else
      local when="now";
      local msg="${@:1}"
    fi

    # date +%s <-- create UNIX epoch time stamp in seconds
    # date --date=@$TS  <-- create datetime string from TS env var
    LT_START=$(date +%s -d $when)
    LT_STOP=""
    LT_LASTMARK=$LT_START
    LT_START_MSG="$msg"
  fi
    _logtime-save
    echo "$LT_START: $LT_START_MSG"
    echo "Now type logtime-mark <+/- offeset> notes about this time mark"
}

# Marks define a length of time if no length is given in hms, then:
# markdur = curtime-LT_START-markdur_total
#
# 123423313123 Starting to do something
# 363 This is the first mark for 0h6m3s
# 3600 This is second mark string   for 1h
# 1800 This thrid task lasted 0h30m0s
# 9003 marktime_total 
logtime-mark() {
  local curtime=$(date +%s)
  local dur=0
  dur=$(_logtime-hms-to-seconds  $1)
 
  if [ "$dur" -eq 0 ] 2>/dev/null  # 0 if not an hms string
  then
    dur=$(( $curtime - $LT_LASTMARK ))
    msg="$@"
  else
    msg="${@:2}"
  fi

  LT_LASTMARK=$curtime

  IFS_ORIG=$IFS
  (( LT_MARK_TOTAL += dur ))
  IFS=$'\n'  
  LT_ARRAY+=("$dur $msg")
  IFS=$IFS_ORIG

  _logtime-save
}

_logtime-stop() {
  echo "LT_STOP is $LT_STOP"
  if [ ! -z "$LT_STOP" ]; then
    return -1 # LT_STOP is not empty, deny user, must unstop first
  else 
    LT_STOP=$(date +%s)
    LT_DURATION=$((LT_STOP - LT_START))
    LT_STOP_MSG=${@:1}
    logtime-mark "$LT_STOP_MSG"
  fi

  _logtime-save
}

_logtime-hms(){
  local h=$(($1 / 3600));
  local m=$((($1 % 3600) / 60));
  local s=$(($1 % 60));
  echo "${h}h${m}m${s}s";
}

_logtime-hms-to-seconds(){
  seconds=$(echo $1 | awk -F'[hmd:]' \
    '{ print ($1 * 3600) + ($2 * 60) + $3 }')
 echo $seconds
}

_logtime-elapsed-hms(){
  local ts=$LT_STOP
  if [ -z "$LT_STOP" ]; then
    ts=$(date +%s)
  fi

  local elapsed=0  
  elapsed=$((ts - LT_LASTMARK))
  local elapsedHms=$(_logtime-hms $elapsed)
  echo $elapsedHms 
}

_logtime-prompt(){
  PS1='$(_logtime-elapsed-hms) > '
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
  local elapsedHms=$(_logtime-hms $elapsed)
  local datestr=$(date --date="@$LT_START")
  echo "LT_START=$LT_START # ($datestr, elapsed:$elapsedHms)"
  echo "LT_START_MSG=$LT_START_MSG"
  echo "LT_ARRAY:"
  logtime-marks
}


logtime-marks(){
  IFS_ORIG=$IFS
  IFS=$"\n"
  for line in "${LT_ARRAY[@]}"; do
     IFS=' ' read left right <<< "$line"
     local deltatime=$(_logtime-hms $left)
     printf "%s %s for %s\n" $left "$right" $deltatime
  done;
  IFS=$IFS_ORIG
}

logtime-mark-change() {
  if [ -z $2 ]; then
      printf 'Changing %s (ctrl+c to cancel)\n' "${LT_ARRAY[$1]}"
      read line 
      LT_ARRAY[$1]=$line 
  else
      local msg="${@:2}"
      LT_ARRAY[$1]="$msg"
  fi
}

logtime-commits(){
  commits=$(ls -1 $LT_COMMIT_DIR)
  for commit in ${commits[@]}
  do
      printf "%s %s\n" "$commit" "$(date --date="@$commit")"
  done
}

logtime-help(){
helptext='
Logtime uses Unix date command to create Unix timestamps.
Start with an intention:

  logtime-start working on invoices for logtime

This starts a timer. Mark time by stating what you have 
done while the timer is running:

  logtime-mark "editing logfile.sh"
  logtime-mark "added first draft of instructions"

Get the status by: logtime-status
Restore state: logtime-load <timestamp> # no argument will list all possible
Commit the list of duration marks: logtime-commit  # writes to $LT_TIMELOG
'
  echo "$helptext"
}

# Development
_logtime-dev-parse() {
  while IFS= read -r line; do  #get the whole line, no IFS
      IFS=.; tokens=($line)    # now IFS is .
      local tsHuman=$(date -d@${tokens[0]} 2> /dev/null) 
      if [ ! -z "$tsHuman" ]
      then
        printf '%s\n' "$tsHuman"
        printf '%s\n\n' ${tokens[1]} 
      fi
      IFS=$' \t\n'
  done < "$LT_TIMELOG" 
  IFS=$' \t\n'
}
