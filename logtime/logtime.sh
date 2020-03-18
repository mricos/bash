#!/bin/bash
#LT_DIR=~/src/mricos/bash/logtime
LT_DIR=~/.logtime
LT_APP=$LT_DIR/logtime.sh
LT_STATE_DIR=$LT_DIR/state
LT_COMMIT_DIR=$LT_DIR/commits
LT_DATA_DIR=$LT_DIR/data

logtime-webserver() {

  while true; do  
    echo -e "HTTP/1.1 200 OK\r\n$(date)\r\n\r\n$(cat $1)" | nc -vl 8080; 
  done
}


logtime-now(){
  echo $(date +%s)
}
logtime-stamp-to-tokens(){
  for f in $1
  do
    echo "Processing $f file..."
    # take action on each file. $f store current file name
    #cat $f
    local basename=$(basename $f)
    bar=(`echo $basename | tr '.' ' '`)
    local day=$(date +"%D %a" -d@${bar[0]})
    echo $basename
    printf '%s %s\n'  "$r"  "$LT_START_MSG"
  done
}

alias stamp='logtime-data-stamp'
logtime-data-stamp() {
  local dest="$LT_DATA_DIR/$(date +%s).$1"
  echo "Writing to  $dest"
  echo "Paste then ctrl-d on newline to end."
  cat >> $dest
}


logtime-clear(){
  LT_START=""
  LT_START_MSG=""
  LT_MARK_TOTAL=0
  LT_LASTMARK=0
  LT_ARRAY=()
}

logtime-info(){
    declare -p  ${!LT_@} 
}

logtime-save(){
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

logtime-selectfile() {
  local dir=$1
  echo "Select from: $dir" 
  local filenames=""
  local listing=$(ls -1 "$1")
  readarray -t filenames <<< "$listing";
  for i in "${!filenames[@]}"  #0 indexing ${!varname[@]} returns indices
  do
    local msg=$(source "$1/${filenames[$i]}"; echo "$LT_START_MSG")  
    echo "$((i+1)))  ${filenames[$i]}: $msg"
  done

  read filenum 
  filenum=$((filenum-1))
  eval "$2=\"$1/${filenames[$filenum]}\""   # Assign on the left and right!
}

logtime-restore(){
  local file=$1
  if [ -z $file ]; then
    logtime-selectfile $LT_STATE_DIR file   #env file var set by selectfile 
  fi
  logtime-source $file
}

logtime-restore-old-notneeded(){
  local infile="$1"
  if [ -z $1 ]; then
    echo "No state file given. Select from:"
    echo ""
    local listing=$(ls -1 $LT_STATE_DIR)
    local filenames=""
    readarray -t <<<"$listing" filenames
    for i in "${!filenames[@]}"  #0 indexing ${!varname[@]} returns indices
    do
      echo "$((i+1)))  ${filenames[$i]}" 
    done
    read filenum 
    filenum=$((filenum-1))
    local infile="$LT_STATE_DIR/${filenames[$filenum]}"
    echo "$infile"
  fi

  # load the variables
  while read -r line
  do
    if [[ $line == declare\ * ]]
    then
        tokens=($(echo $line))  # () creates array
        # override flags with -ag global
        local cmd="${tokens[0]} -ag ${tokens[@]:2}" 
        echo $cmd
        eval  "$cmd"
    fi
  done < "$infile"

  export ${!LT_@}
}

logtime-source(){
  # load the variables
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
logtime-get-latest-commit(){
  local files=($(ls -1t $LT_COMMIT_DIR )) # array of files
  echo "${files[@]}"
}

logtime-commit(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
    return -1
  fi 
  
  if [ -z $LT_STOP ]; then
    echo "LT_STOP is empty. Use logtime-stop [offset] [message]."
    return -1
  fi 

  if [ -z $1 ] # if there is one or more arguments, treat it as string
     then
        local commitmsg=$LT_STOP_MSG
      else
        local commitmsg="${@:1}"
  fi 

  logtime-stop # will not return if stop has not been called 
  local datestart=$(date --date=@$LT_START)
  local datestop=$(date --date=@$LT_STOP)
  local duration=$(logtime-hms $LT_DURATION)
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

  logtime-save
  mv "$LT_STATE_DIR/$LT_START" "$LT_COMMIT_DIR/$LT_START"
  echo "moved $LT_STATE_DIR/$LT_START $LT_COMMIT_DIR/$LT_START"
  logtime-clear
}

logtime-is-date(){
  date -d "$1" &>/dev/null; echo $? # returns 0 if true, 1 if error
}

logtime-str2time(){
  date +%s -d "$1"
}

logtime-start() {
  if [ ! -z $LT_START ]; then
    echo "LT_START not empty. Use logtime-clear to clear."
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
    logtime-save
    echo "$LT_START: $LT_START_MSG"
    echo "Now type logtime-mark <+/- offeset> notes about this time mark"
}

logtime-start-msg() {
  LT_START_MSG="$@"
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
  dur=$(logtime-hms-to-seconds  $1)
 
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

  logtime-save
}

logtime-setstart() {
  local now=$(date +%s)
  local seconds=$(logtime-hms-to-seconds $1)
  LT_START=$((now-seconds))
}

logtime-setstop() {
  local seconds=$(logtime-hms-to-seconds $1)
  LT_STOP=$((LT_START+seconds))
}

logtime-unstop() {
  LT_STOP=""
}
logtime-stop() {
  echo "LT_STOP is $LT_STOP"
  if [ ! -z "$LT_STOP" ]; then
    return -1 # LT_STOP is not empty, deny user, must unstop first
  else 
    LT_STOP=$(date +%s)
    LT_DURATION=$((LT_STOP - LT_START))
    LT_STOP_MSG=${@:1}
    logtime-mark "$LT_STOP_MSG"
  fi

  logtime-save
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
  local datestr=$(date --date="@$LT_START")
  echo "LT_START=$LT_START # ($datestr, elapsed:$elapsedHms)"
  echo "LT_START_MSG=$LT_START_MSG"
  echo "LT_ARRAY:"
  logtime-marks
}

logtime-prompt(){
  PS1='$(logtime-elapsed-hms) > '
}

logtime-elapsed-hms(){
  local ts=$LT_STOP
  if [ -z "$LT_STOP" ]; then
    ts=$(date +%s)
  fi

  local elapsed=0  
  elapsed=$((ts - LT_LASTMARK))
  local elapsedHms=$(logtime-hms $elapsed)
  echo $elapsedHms 
}

logtime-start-set(){
    if date -d "$1" 2>: 1>:; then  # test, send stdio to /dev/null
      local when=$1;
    else
      local when="now";
    fi
    LT_START=$(date +%s -d $when)
    LT_LASTMARK=$LT_START
}

logtime-start-increment(){
  local offset=$(logtime-hms-to-seconds $1)
  LT_START=$(($LT_START + $offset))
}

logtime-marks(){
  IFS_ORIG=$IFS
  IFS=$'\n'
  for line in ${LT_ARRAY[@]}; do
     IFS=' ' read left right <<< "$line"
     deltatime=$(logtime-hms $left)
     printf "%s %s for %s\n" $left $right $deltatime
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
# Porcelain
alias ltls="cat $LT_TIMELOG"


logtime-help(){
helptext='
Logtime uses Unix date command to create Unix timestamps.
Start with an intention:

  logtime-start working on invoices for logtime

This starts a timer. Mark time by stating what you have 
done while the timer is running:

  logtime-mark editing logfile.sh
  logtime-mark added first draft of instructions

Get the status by: logtime-status

Save state along the way: logtime-save

Restore state: logtime-load <timestamp> # no argument will list all possible

Commit the list of duration marks: logtime-commit  # writes to $LT_TIMELOG
'
  echo "$helptext"
}

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
  done < "$LT_TIMELOG" 
  IFS=$' \t\n'
}
logtime-dev-parse2() {
  local tsHuman=""
  IFSOLD=$IFS
  while IFS= read -r line; do  #get the whole line, no IFS
      IFS=' '; tokens=($line)    # now IFS is space 
      if [[ $tokens[0] > 600000 ]]; then
        tsHuman=$(date -d@${tokens[0]} 2> /dev/null) 
      else
        tsHuman=$(logtime-hms ${tokens[0]} 2> /dev/null) 
      fi

      IFS=$' \t\n'
      printf '%s %s \n' "$tsHuman" $line

  done < "$LT_TIMELOG" 
  IFS=$' \t\n'
}
