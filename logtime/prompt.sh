logtime-load-commit(){
  if [[ $# -eq  0 ]]; then
    _logtime-load-interactive commits 
  else 
    _logtime-source "$1"
  fi
  logtime-prompt              # changes PS1 to show elapsed time
}

logtime-load(){
  if [[ $# -eq  0 ]]; then
    _logtime-load-interactive states
  else 
    _logtime-source "$1"
  fi
  logtime-prompt              # changes PS1 to show elapsed time
}

logtime-prompt(){
  # Logtime's prompt shows how much time since last mark.
  PS1_ORIG="$PS1"
  PS1_LOGTIME_MSG='$(_logtime-elapsed-hms)'
  local msg='$(_logtime-elapsed-hms)'
  PS1="$msg> "
}

logtime-prompt-reset(){
  PS1="$PS1_ORIG"
}

