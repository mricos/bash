#bin/bash
TIMELOG=./time.txt
LT_STATE_DIR=${LT_STATE_DIR:=".logtime/state"}
LT_COMMIT_DIR=${LT_COMMIT_DIR:=".logtime/commit"}
LT_DATA_DIR=${LT_DATA_DIR:=".logtime/data"}

# Logtime uses Unix date command to create Unix timestamps.
# Start with an intention:
#   logtime-start working on invoices for logtime
#
# This starts a timer. Mark time by stating what you have 
# done while the timer is running:
#
#   logtime-mark editing logfile.sh
#   logtime-mark added first draft of instructions
#
# Get the status by:
#
#   logtime-status
#
# Save state along the way:
#
#   logtime-save
#
# Restore state:
#
#   logtime-load <timestamp> # no argument will list all possible
# 
# Commit the list of duration marks:
#
#   logtime-commit  # writes to $LT_TIMELOG
#
# View time:
#
#   cat $LT_TIMELOG
#
logtime-clear(){
  LT_START=""
  LT_START_MSG=""
  LT_MARK_TOTAL=0
  LT_LASTMARK=0
  LT_ARRAY=()
}

logtime-save(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local outfile="$LT_STATE_DIR/$LT_START"
    export ${!LT_@}
    declare -p  ${!LT_@}  > "$outfile"
    printf '%s\n' "Wrote to $outfile"
  fi
}

logtime-recall(){
  local infile="$LT_STATE_DIR/$1"
  if [ ! -f $infile ]; then
    echo "State file not found. Select from:"
    ls $LT_STATE_DIR
  else
    echo "Loading from $infile"
    cat $infile
    echo "Sourcing $infile"
    source "$infile"
    echo $LT_START
    export ${!LT_@}
    export LT_START
  fi
}

logtime-commit(){
  IFSOLD=$IFS
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local datestr=$(date --date=@$LT_START)
    local outfile="$LT_COMMIT_DIR/$LT_START"
    echo "$LT_START $LT_START_MSG ($datestr)"
    #IFS=$'\n'; printf '%s\n' ${LT_ARRAY[@]} ;
    logtime-marks
    IFS=$IFSOLD
  fi
}

logtime-commit2(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    #local datestr=$(date +%D --date=@$LT_START)
    local datestr=$(date  --date=@$LT_START)
    printf '%s\n%s\n'  "$datestr"  "$LT_START_MSG"
    logtime-marks2
    printf '\n' 
  fi

}

logtime-restore(){
    source $1
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
    LT_LASTMARK=$LT_START
    LT_START_MSG="$msg"
  fi

    echo "$LT_START: $LT_START_MSG"
    echo "Now type logtime-mark <+/- offeset> notes about this time mark"
}

# Marks define a length of time
# if no length is given in hms, then:
# markdur = curtime-LT_START-markdur_total
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
}

logtime-stop() {
  LT_STOP=$(date +%s)
  LT_DURATION=$((LT_STOP - LT_START))
}

logtime-string() {
  echo "\""${@:3}"\""
}
logtime-string-old() {
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
  local datestr=$(date --date="@$LT_START")
  printf '\n'
  echo "LT_START=$LT_START # ($datestr, elapsed:$elapsedHms)"
  echo "LT_START_MSG=$LT_START_MSG"
  echo "TIMELOG=$TIMELOG"
  echo "LT_ARRAY:"
  logtime-marks
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
logtime-increment(){
  local offset=$(logtime-hms-to-seconds $1)
  LT_START=$(($LT_START + $offset))
}

logtime-marks2(){
  IFS_ORIG=$IFS
  IFS=$'\n'
  for line in ${LT_ARRAY[@]}; do
     IFS=' ' read left right <<< "$line"
     deltatime=$(logtime-hms $left)
     printf '%s (%s)\n' $right $deltatime
  done; 
  IFS=$IFS_ORIG
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
  printf 'Changing %s (ctrl+c to cancel)\n' "${LT_ARRAY[$1]}"
  read line 
  $LT_ARRAY[$1]=$line 
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

  done < "$TIMELOG" 
  IFS=$' \t\n'
}
