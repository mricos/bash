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

logtime-start() {
  TS_START=$(date-ts)
  LT_START_MSG="$@"
  echo "Start timer: $TS_START $@"
}
logtime-continue() {
  echo "Todo: figure out pausing."
#  TS_START=$(date-ts)
#  TS_START=$(($TS_START - $SECONDS))
#  SECONDS=$((TS_END - TS_START))
#  echo "Start continuing: $SECONDS $@"
}
logtime-stop() {
  TS_END=$(date-ts)
  LT_STOP_MSG=$@
  SECONDS=$((TS_END - TS_START))
  hms=$(logtime-duration $SECONDS) 
  echo "Timer stopped with: $hms"
  echo "startmsg: $LT_START_MSG"
  echo "endmsg: $LT_STOP_MSG"
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

alias lt="logtime-logmsg $@"
alias ltstart="logtime-start $@"
alias ltstop="logtime-stop $@"
alias lth="logtime-hms $@"
alias ltd="logtime-ts-human $@"
alias ltp="logtime-project $@"
alias ltcat="cat $TIMELOG"
alias ltls="logtime-ls"
alias ltlog="logtime-ls"
