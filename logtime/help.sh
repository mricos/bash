logtime-help(){
helptext='
Logtime uses Unix date command to create Unix timestamps.
Start with an intention:

  logtime-start working on logtime

This starts a timer. Mark time by stating what you have 
done while the timer is running:

  logtime-mark "editing logfile.sh"
  logtime-mark "added first draft of instructions"

Get the status by: logtime-status
Restore state: logtime-load <timestamp> # no argument will list all possible
Commit the list of duration marks: logtime-commit  # writes to $LT_TIMELOG

Mac users need to install:
brew install coreutils  # installs gdate
brew install bash
Add /opt/homebrew/bin/bash to /etc/shells
sudo chpass -s /usr/local/bin/bash
'
  echo "$helptext"
}

_logtime-start-text(){
    cat <<EOF

Now type lines like:

  logtime-mark 1h20m researched edgar codd
  logtime-mark 0h20m break, stretch
  logtime-mark  2h20m testing framework

  logtime-store "https://en.wikipedia.org/wiki/Edgar_F._Codd"

And 

  logtime-marks     # show all marks for current sequence
  logtime-meta      # show meta for current sequence
  logtime-stores    # show all stores for current sequence
  logtime-status    # info about the sequence
  logtime-commit    # move from live states to commit status in db 
  logtime-load      # load from a list of live states
  logtime-report    # generates html for all commits

EOF
}
