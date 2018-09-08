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

logtime-ts() {
  TS=$(date-ts)
  echo "$TS $@" >> $TIMELOG
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

alias lt="logtime-logmsg $@"
alias ltd="logtime-ts-human $@"
alias ltcat="cat $TIMELOG"
alias ltls="logtime-ls"
alias ltlog="logtime-ls"
