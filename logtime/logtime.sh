s(){ source $BASH_SOURCE; }
v(){ vi $BASH_SOURCE; }
c(){ shellcheck $BASH_SOURCE; }
TIMELOG=~/time.txt

date-ts(){
    date +%s
}

date-ts2dt(){
  if [[ "$1" ]]; then  
    date --date=@$1; 
  else
    date;
  fi

}

logtime-clear(){
  LT_START=""
  LT_STOP=""
  LT_STOP_MSG=""
}
logtime-start() {
  if [ ! -z "$LT_START" ]; then
    echo "LT_START not empty. Use ltclear to clear."
  else
    LT_START=$(date-ts)
    LT_TIMER=$LT_START
    LT_DATA_ARRAY=(one two three)
    LT_START_MSG="$@"
    echo "Start timer: $LT_START $@"
  fi
}
 

logtime-stop() {
  LT_STOP=$(date-ts)
  LT_STOP_MSG=$@
  SECONDS=$((TS_END - TS_START))
  hms=$(logtime-duration $SECONDS) 
  echo "Timer stopped with: $hms"
  echo "startmsg: $LT_START_MSG"
  echo "endmsg: $LT_STOP_MSG"
}

logtime-continue() {
  echo "Todo: figure out pausing."
#  LT_START=$(date-ts)
#  LT_START=$(($LT_START - $SECONDS))
#  SECONDS=$((LT_END - LT_START))
#  echo "Start continuing: $SECONDS $@"
}

logtime-ts() {
  TS=$(date-ts)
  echo "$TS $@" >> $TIMELOG
}

logtime-hms() {
  TS=$(date-ts)
  logtime-stop
  echo "$TS $hms $LT_PROJECT $LT_START_MSG $LT_STOP_MSG $@" >> $TIMELOG
}


logtime-ts-unix() {
  TS=$(date-ts)
  echo "$TS $@" 
  echo "$TS $@" >> $TIMELOG
}

logtime-ts-human() {
  TS=$(date +%s --date="$1")
  all=$@
  first=$1
  remain=${all#$first}
  echo "$TS $remain" 
  echo "$TS $remain" >> $TIMELOG
}

logtime-logmsg(){
  TS=$(date +%s)
  echo "$TS $LT_PROJECT $@" >> $TIMELOG
}

logtime-ls(){
   cat $TIMELOG
}

logtime-duration(){
  H=$(($1 / 3600));
  M=$((($1 % 3600) / 60));
  S=$(($1 % 60));
  echo "${H}h${M}m${S}s";
}

logtime-project(){
  LT_PROJECT=$1
}

logtime-status(){
  TS=$(date +%s)

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
  echo "LT_DATA_ARRAY: ${LT_DATA_ARRAY[@]}"
}

logtime-hms-to-seconds(){
  seconds=$(echo $1 | awk -F'[hmd:]' \
    '{ print ($1 * 3600) + ($2 * 60) + $3 }')
 echo $seconds
}

alias lt="logtime-logmsg $@"
alias ltstart="logtime-start $@"
alias ltstop="logtime-stop $@"
alias ltstatus="logtime-status"
alias lth="logtime-hms $@"
alias ltd="logtime-ts-human $@"
alias ltp="logtime-project $@"
alias ltcat="cat $TIMELOG"
alias ltls="logtime-ls"
alias ltlog="logtime-ls"
alias ltclear="logtime-clear"
