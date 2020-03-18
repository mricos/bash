#c(){ shellcheck $BASH_SOURCE; }
QIKREMOTEUSER=mricos
QIKREMOTEHOST=lenan.net
QIKREMOTEHOST=localhost
QIKREMOTEDIR=~/qik/qik

qik(){
  if [[ $# > 0 ]]; then  # always do this
    TS=$(date +%s)
    echo "Qik'd $1 with TS=$TS"
    cp $1 .qik/$1.$TS
    
  fi
  if [[ $# == 2 ]]; then  # assume second arg is comment string
    echo $TS $1: $2 >> .qik/log
  fi
}

qik-ls(){
 ls $1 .qik/*
}

qik-pull(){
  # all (recursive, verbose, progress)
  rsync -avP  $QIKREMOTEUSER@$QIKREMOTEHOST:$QIKREMOTEDIR/ .qik/
}
qik-push(){
  # all (recursive, verbose, progress)
  rsync -avP .qik/ $QIKREMOTEUSER@$QIKREMOTEHOST:$QIKREMOTEDIR
}

qik-make-remote(){
 ssh $QIKREMOTEUSER@$QIKREMOTEHOST mkdir $QIKREMOTEDIR
}

qik-ls-remote(){
 ssh $QIKREMOTEUSER@$QIKREMOTEHOST ls $QIKREMOTEDIR
}

qik-get(){
  cat .qik/*.$1
}
qik-log(){
  logfile=.qik/log
  if [[ $# == 0 ]]; then
    cat $logfile
  fi

  if [[ $1 == "pretty" ]]; then
    while read line; do 
        ts=${line:0:10}
        msg=${line:11}
        #tokens=($(echo $line | sed 's/\s/\n/g'))
        #$tokens[@]
        #$token 
        val=$(date --date=@$ts); 
        printf "$val ($ts)\n$msg\n\n";
    done < $logfile
  fi

  if [[ $1 == "iso" ]]; then
    while read line; do 
        ts2iso ${line:0:10}; 
        printf "$retvar\n$line\n"
    done < $logfile
  fi
}

alias qls="qik-ls"
alias qlog="qik-log"
alias q="qik"
