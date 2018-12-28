TIMELOG=~/time.txt

# date +%s <-- create UNIX epoch time stamp in seconds
# date --date=@$TS  <-- create datetime string from TS env var

logtime-clear(){
  LT_START=""
  LT_STOP=""
  LT_TIMER=""
  LT_STOP_MSG=""
  LT_ARRAY=()
}
logtime-start() {
  if [ ! -z "$LT_START" ]; then
    echo "LT_START not empty. Use ltclear to clear."
  else
    LT_START=$(date +%s)
    LT_TIMER=$LT_START
    LT_ARRAY=()
    LT_START_MSG="LT_START.$@"
    echo "Start timer: $LT_START $@"
  fi
}

logtime-add(){
    LT_ARRAY+=($(logtime-string $@))
}

logtime-stop() {
  LT_STOP=$(date +%s)
  LT_STOP_MSG=$@
  local SECONDS=$((TS_END - TS_START))
  hms=$(logtime-duration $SECONDS) 
  echo "Timer stopped with: $hms"
  echo "startmsg: $LT_START_MSG"
  echo "endmsg: $LT_STOP_MSG"
}

logtime-continue() {
  echo "Todo: figure out pausing."
#  LT_START=$(date +%s)
#  LT_START=$(($LT_START - $SECONDS))
#  SECONDS=$((LT_END - LT_START))
#  echo "Start continuing: $SECONDS $@"
}

logtime-parse() {
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


logtime-string() {
  local ts=$(date +%s)
  echo "$ts.\""$@"\""
}

logtime-logmsg(){
  local ts=$(date +%s)
  echo "$ts $@" >> $TIMELOG
}

logtime-ts-human() {
  TS=$(date +%s --date="$1")
  all=$@
  first=$1
  remain=${all#$first}
  echo "$TS $remain" 
}

logtime-status(){
  TS=$(date +%s)

  if [ -z "$LT_START" ]; then
    echo "
   No timer started. 
   Use logtime-start <optional message of intention>
"
    return 1
  fi
 
  if [ -z "$LT_STOP" ]; then
     LT_ELAPSED=$(($TS-$LT_START)) # fails if LT_START not defined
  else
     LT_ELAPSED=$(($LT_STOP - $LT_START))
  fi
 
  echo "TS: $TS"
  echo "LT_START: $LT_START"
  echo "LT_STOP: $LT_STOP"
  echo "LT_PROJECT: $LT_PROJECT"
  hms=$(logtime-duration $LT_ELAPSED)
  echo "LT_ELAPSED: $LT_ELAPSED ($hms)"
  echo "LT_START_MSG: $LT_START_MSG"
  echo "LT_STOP_MSG: $LT_STOP_MSG"
  echo "TIMELOG: $TIMELOG"
  echo "LT_ARRAY:"
  printf "%s\n" "${LT_ARRAY[@]}"

}

logtime-duration(){
  H=$(($1 / 3600));
  M=$((($1 % 3600) / 60));
  S=$(($1 % 60));
  echo "${H}h${M}m${S}s";
}

logtime-hms() {
  TS=$(date +%s)
  logtime-stop
  echo "$TS $hms $LT_PROJECT $LT_START_MSG $LT_STOP_MSG $@" >> $TIMELOG
}

logtime-hms-to-seconds(){
  seconds=$(echo $1 | awk -F'[hmd:]' \
    '{ print ($1 * 3600) + ($2 * 60) + $3 }')
 echo $seconds
}

# Porcelain
alias lt="logtime-logmsg $@"
alias ltstart="logtime-start $@"
alias ltstop="logtime-stop $@"
alias ltstatus="logtime-status"
alias lth="logtime-hms $@"
alias ltd="logtime-ts-human $@"
alias ltp="logtime-project $@"
alias ltls="cat $TIMELOG"
alias ltcat="cat $TIMELOG"
alias ltlog="cat $TIMELOG"
alias ltclear="logtime-clear"
