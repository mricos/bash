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
  echo "Start timer: $TS_START $@"
}
logtime-stop() {
  TS_END=$(date-ts)
  SECONDS=$((TS_END - TS_START))
  hms=$(logtime-duration $SECONDS) 
  echo "Timer stopped with: $hms"
}

logtime-ts() {
  TS=$(date-ts)
  echo "$TS $@" >> $TIMELOG
}

logtime-hms() {
  TS=$(date-ts)
  echo "$TS $hms $@" >> $TIMELOG
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

alias lt="logtime-logmsg $@"
alias ltd="logtime-ts-human $@"
alias ltcat="cat $TIMELOG"
alias ltls="logtime-ls"
alias ltlog="logtime-ls"
