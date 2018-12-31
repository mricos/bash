TIMELOG=~/time.txt

# date +%s <-- create UNIX epoch time stamp in seconds
# date --date=@$TS  <-- create datetime string from TS env var

logtime-clear(){
  LT_START=""
  LT_STOP=0
  LT_DURATION=0
  LT_ELAPSED=0
  LT_START_MSG=""
  LT_STOP_MSG=""
  LT_MARK=0
  LT_MARK_DURATION=0
  LT_LASTMARK=0
  LT_DURATION=0
  LT_ARRAY=()
}
logtime-start() {
  if [ ! -z $LT_START ]; then
    echo "LT_START not empty. Use logtime-clear to clear."
  else
    LT_START=$(date +%s)
    LT_MARK=$LT_START
    LT_DURATION=0
    LT_ELAPSED=0
    LT_START_MSG=$@
    echo "Start timer: $LT_START $@"
  fi
}

logtime-mark() {
  LT_LASTMARK=$LT_MARK
  LT_MARK=$(date +%s)
  LT_MARK_DURATION=$((LT_MARK - LT_LASTMARK))
  IFS_ORIG=$IFS
  IFS=$'\n'  
  LT_ARRAY+=($(logtime-string $LT_MARK.$LT_MARK_DURATION $@))
  IFS=$IFS_ORIG
}

logtime-stop() {
  LT_STOP=$(date +%s)
  LT_DURATION=$((LT_STOP - LT_START))
}

logtime-string() {
  echo "$1.\""${@:2}"\""
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

  TS=$(date +%s)
  LT_ELAPSED=$((TS - LT_START))
  local elapsedHms=$(logtime-hms $LT_ELAPSED)
  echo "LT_START: $LT_START"
  echo "LT_STOP: $LT_STOP"
  echo "LT_DURATION: $LT_DURATION ( $(logtime-hms $LT_DURATION) )"
  echo "LT_ELAPSED: $LT_ELAPSED ( $elapsedHms )"
  echo "LT_MARK: $LT_MARK"
  echo "LT_LASTMARK: $LT_LASTMARK"
  echo "LT_MARK_DURATION: $LT_MARK_DURATION"
  echo "LT_START_MSG: $LT_START_MSG"
  echo "LT_STOP_MSG: $LT_STOP_MSG"
  echo "TIMELOG: $TIMELOG"
  echo "LT_ARRAY:"
  IFS_ORIG=$IFS
  IFS="" 
  for line in ${LT_ARRAY[@]}; do
    printf "mark.%s\n" $line 
  done; 
  IFS=$IFS_ORIG
  echo ""
}

logtime-commit() {
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
  while IFS= read -r line; do
      IFS=.; tokens=($line)
      local tsHuman=$(date -d@${tokens[0]} 2> /dev/null) 
      if [ ! -z "$tsHuman" ]
      then
        printf '%s\n' "$tsHuman"
        printf '%s\n\n' ${tokens[1]} 
      fi
      IFS=$' \t\n'
  done < "$TIMELOG" 
}
