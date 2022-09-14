#!/bin/bash

LT_MAX_MARKS=32000
LT_DIR=~/.logtime
LT_STATES=$LT_DIR/states
LT_COMMITS=$LT_DIR/commits
IFS=$' \t\n'

alias mark="logtime-mark"
alias marks="logtime-marks"
alias ltcat="logtime-marks-cat"
alias filter="logtime-marks-filter"
alias push="logtime-push"
alias pop="logtime-pop"
alias popall="logtime-pop $LT_MAX_MARKS"
alias stack="logtime-peek-stack"

alias store="logtime-store"
alias status="logtime-status"

#######################################################################
#  Helper functions start with _ 
#######################################################################

_logtime-clear(){
  LT_START=""             # set at creation 
  LT_STOP=""              # empty until commit
  LT_START_MSG=""         # set at creation
  LT_COMMIT_MSG=""        # empty until commit
  LT_LASTMARK=$(date +%s) # timestamp
  LT_MARKS=()             # array of strings; duration in seconds
  LT_META=""              # filename of corresponding meta data 
}

_logtime-save(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local outfile=$LT_DIR/states/$LT_START
    local backup=$LT_DIR/backup/$LT_START.backup
    cp  $outfile $backup # 2> /dev/null # outfile does not exist
    export ${!LT_@}
    declare -xp  ${!LT_@}  > "$outfile"
    if [ $? -eq 0 ]; then
      printf '%s\n' "Wrote to $outfile"
    fi
  fi
}

_logtime-select-state() {
  _logtime-objects "$LT_STATES" 
  local listing=$(ls -1 "$LT_STATES")
  local filenames=""
  readarray -t filenames <<< "$listing";
  read -p "Select state to load:" filenum 
  filenum=$((filenum-1))
  _logtime-source "$LT_STATES/${filenames[$filenum]}"
}

logtime-load(){
  if [[ $# -eq  0 ]]; then
    _logtime-load-interactive states
  else 
    _logtime-source "$1"
  fi
  logtime-prompt
}

_logtime-load-interactive(){
  local type=${1:-states} 
  _logtime-objects "$LT_DIR/$type" 
  local listing=$(ls -1 "$LT_DIR/$type")
  local filenames=""
  readarray -t filenames <<< "$listing";
  read -p "Select $type to load:" filenum 
  filenum=$((filenum-1))
  _logtime-clear
  _logtime-source "$LT_DIR/$type/${filenames[$filenum]}"
}

_logtime-source(){
  # reads file with path = $1
  while read -r line
  do
    if [[ $line == declare\ * ]]
    then
        tokens=($(echo $line))  # () creates array
        # override flags with -ag global 
        # since declare does not provide g
        local cmd="${tokens[0]} -ag ${tokens[@]:2}" 
        eval  "$cmd"
    fi
  done < "$1"
  export ${!LT_@}
  logtime-status
}

_logtime-hms(){
  local h=$(($1 / 3600));
  local m=$((($1 % 3600) / 60));
  local s=$(($1 % 60));
  echo "${h}h${m}m${s}s";
}

_logtime-hms-to-seconds(){
  seconds=$(echo $1 | awk -F'[hmd:]' \
    '{ print ($1 * 3600) + ($2 * 60) + $3 }')
 echo $seconds
}

_logtime-elapsed-hms(){
  ts=$LT_STOP
  if [ -z "$LT_STOP" ]; then
    ts=$(date +%s)
  fi
  local elapsed=0  
  elapsed=$((ts - LT_LASTMARK))
  local elapsedHms=$(_logtime-hms $elapsed)
  echo $elapsedHms 
}

_logtime-set-stop-from-marks(){
  local total=0
  for line in "${LT_MARKS[@]}"; do
    IFS=' ' read left right <<< "$line"
    (( total+=$left ))
  done;
  IFS=$' \t\n'
 LT_LASTMARK=$(( LT_START + total ))
 LT_STOP=$(( LT_START + total ))
}

_logtime-get-startmsg(){
  # sources in temp shell via $()
  echo $(source "$1"; echo "$LT_START_MSG")
}

_logtime-objects() {
  local dir=$1 # have to provide dir
  local listing=$(ls -1 "$dir")
  local filenames=""
  readarray -t filenames <<< "$listing";
  for i in "${!filenames[@]}"  #0 indexing ${!varname[@]} returns indices
  do
    #local msg=$(source "$dir/${filenames[$i]}"; echo "$LT_START_MSG")  
    local msg=$(_logtime-get-startmsg "$dir/${filenames[$i]}")  
    echo "$((i+1)))  ${filenames[$i]}: $msg"
  done
}

_logtime-stop() {
  echo "LT_STOP is $LT_STOP"
  if [ ! -z "$LT_STOP" ]; then
    return -1 # LT_STOP is not empty, deny user, must unstop first
  else 
    LT_STOP=$(date +%s)
  fi
  logtime-mark "STOPPED"
  _logtime-save
}

#######################################################################
#   CLI API
#######################################################################
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

logtime-load-old(){
   if [ -z $1 ]              # if first arg does not exist 
     then
       echo "Select state: # filename of corresponding meta data"
       _logtime-select-state
      else
       _logtime-clear        # zeros out all local bash variables LT_*
       _logtime-source $1    # reads in declare statements to set LT_ vars
  fi 
}

logtime-start() {
  local when="now";
  if [ ! -z $LT_START ]; then
    echo "LT_START not empty. Use _logtime-clear to clear."
    return -1
  else
    if date -d "$1" &>/dev/null; then  # test, send stdio to /dev/null
      local when="$1";
      local msg="${@:2}";
    else
      local when="now";
      local msg="${@:1}"
    fi
    echo "When is $when"
    # date +%s <-- create UNIX epoch time stamp in seconds
    # date --date=@$TS  <-- create datetime string from TS env var
    LT_START=$(date +%s -d "$when" )
    LT_STOP=""
    LT_LASTMARK=$LT_START
    LT_START_MSG="$msg"
  fi
    _logtime-save
    echo "$LT_START: $LT_START_MSG"
    echo "Now type logtime-mark <+/- offeset> notes about this time mark"
}

# Marks define a length of time if no length is given in hms, then:
# markdur = curtime-LT_START-markdur_total
#
# 123423313123 Starting to do something
# 363 This is the first mark for 0h6m3s
# 3600 This is second mark string   for 1h
# 1800 This thrid task lasted 0h30m0s
# 9003 marktime_total 

logtime-mark() {
  [ ! -z "$LT_STOP" ] && echo "protected" && return 
  local curtime=$(date +%s)
  dur=0
  dur=$(_logtime-hms-to-seconds  $1)
  if [ "$dur" -eq 0 ]                   # 0 if not an hms string
  then
    dur=$(( $curtime - $LT_LASTMARK ))
    local msg="${@:1}"
  else
    local msg="${@:2}"
  fi

  # If the user adds a duration and it is less than 
  # (curtime - LT_LASTMARK) then add the user's duration
  # to LASTMARK. Otherwise LASTMARK=currentTime.

  # Rather than conditional else, do it in two lines like this:
  local lastmark=$LT_LASTMARK
  (( dur < curtime - lastmark )) &&  LT_LASTMARK=$((LT_LASTMARK + dur));
  (( dur >= curtime - lastmark )) && LT_LASTMARK=$curtime;
  IFS_ORIG=$IFS
  IFS=$'\n'  
  LT_MARKS+=("$dur $msg")              # array created on newline boundaries
  IFS=$IFS_ORIG
  _logtime-save
}

logtime-overwrite(){
  unset LT_MARKS
  logtime-append $1
}

logtime-append(){
  local src=$1
  while read line                # read parses on \n comming from < $src
  do
    LT_MARKS+=( "$line" );
    printf "pushed to LT_MARKS: %s\n" "$line"
  done < $src
}

logtime-rebase(){
  local total=0
  LT_LASTMARK=$LT_START
  for line in "${LT_MARKS[@]}"; do
    dur="${line%% *}"                 # substring removal
    echo "$dur $line"                 # first token is duration in seconds
    ((total+=$dur))
  done
  (( LT_LASTMARK = LT_START + total ))
  printf "        Total seconds:%s (%2.2f days)\n" \
      $total $(jq -n "$total/(60*60*24)") > /dev/stderr
  printf "LT_LASTMARK-LT_START: %s (%2.2f days)\n" \
      $((LT_LASTMARK-LT_START)) $(jq -n "$total/(60*60*24)")  > /dev/stderr
}

logtime-append-2(){
  $dur=$1                              # first cli arg is duration in seconds
  msg="${@:2}"                         # all cli args after first token
  LT_MARKS+=("$dur $msg");

}


LT_STACK=()
logtime-push-hms(){
  local dur=$(_logtime-hms-to-seconds  $1)
  local msg="${@:2}"
  LT_STACK+=("$dur $msg")
}

logtime-pop(){
  local N=${1:-1}                  # pop 10 will return 
  local n=0
  source $LT_DIR/stack             #ssot-write: single source of truth

  while (( n < N )) ; do
    (( n++ )) 
    [ ! -z "$LT_STACK" ] \
        && echo "${LT_STACK[-1]}" \
        2> /dev/null;
    [ ! -z "$LT_STACK" ] \
        && unset LT_STACK[-1] 2> /dev/null;
  done

  declare -xp  LT_STACK  > \
      $LT_DIR/stack                #ssot-read:stack 

  [ -z "$LT_STACK" ] \
      && { echo "empty stack"; return -1; }
}

# Push to the one and only stack. Each operation writes
# to disk so that te stack is shared globally. #SharpTools
logtime-push(){
  local msg="${@}"                 # assume arguments are a string to push
  local src="/dev/stdin"           # is set to null if args are passed
  source $LT_DIR/stack             # Single source of truth is disk

  if [ ! -z "$msg" ]               # if not unset or empty string 
  then                             # then we we will all command line string
    LT_STACK+=("$msg");
    declare -xp  LT_STACK  > \
                 $LT_DIR/stack     # write sigle source of truth
    src=/dev/null                  # this will short circuit read on stdin
    return 0
  else                             # else push lines from stdin
    while read line                # read parses on \n comming from < $src
    do
      LT_STACK+=( "$line" );
      printf "pushed: %s\n" "$line"
    done < "$src"
  
    #export LT_STACK
    declare -xp  LT_STACK  > $LT_DIR/stack
  fi
}


logtime-peek-stack(){
  source $LT_DIR/stack
  for line in "${LT_STACK[@]}"; do
    echo "$line"
  done
}

logtime-states(){
  _logtime-objects "$LT_STATES" 
}

logtime-store(){
  echo "$(date +%s) $@" >> $LT_DIR/store/$LT_START.store
}

logtime-stores(){
  cat $LT_DIR/store/$LT_START.store
}

logtime-commits(){
  _logtime-objects "$LT_COMMITS"
#  for commit in $(ls $LT_COMMITS)
#  do
#    printf "%s %s\n" "$commit" "$(date --date="@$commit")"
#    printf "  %s\n" "$commit" "$(date --date="@$commit")"
#  done
}

logtime-commit(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
    return -1
  fi 
  
  if [ -z $1 ] # if there is one or more arguments, treat it as string
  then
    #echo "LT_STOP is empty. Use logtime-stop [offset] [message]."
    commitmsg="Committed $LT_START_MSG at $LT_STOP"
  else
    local commitmsg="${@:1}"
  fi 

  LT_COMMIT="$commitmsg"

  _logtime-stop # will not return if stop has not been called 
  local datestart=$(date --date=@$LT_START)
  local datestop=$(date --date=@$LT_STOP)
  local deltaSeconds=$(($LT_STOP - $LT_START))

  local totalMarks=0
  ((totalMarks = LT_LASTMARK-LT_START))
  echo "Total marks:"  $(jq -n "$totalMarks/(60*60*24)")

  local duration=$(_logtime-hms $deltaSeconds )
  printf 'logtime-marks: \n'
  logtime-marks
  printf '%s\n' "Start message: $LT_START_MSG"
  printf 'Date start: %s\n'  "$datestart" 
  printf 'Date stop: %s\n'  "$datestop" 
  printf '%s %s\n' "Open duration:" $duration
  printf '%s\n' "Commit msg: $commitmsg"
  printf 'Commit? ctrl-c to cancel, return to continue\n'
  read ynCommit

  _logtime-save
  mv "$LT_STATES/$LT_START" "$LT_COMMITS/$LT_START"
  rm "$LT_STATES/$LT_START.*" 
  echo "moved $LT_STATES/$LT_START $LT_COMMITS/$LT_START"
  _LT_LAST_START=$LT_START
  _logtime-clear
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
  local dur=$(($LT_STOP - LT_START))
  local elapsedHms=$(_logtime-hms $elapsed)
  local datestr=$(date --date="@$LT_START")
  echo
  echo "  LT_START=$LT_START ($datestr, elapsed:$elapsedHms)"
  echo "  LT_START_MSG=$LT_START_MSG"
  echo "  LT_STOP=$LT_STOP ($datestr, duration: $dur)"
  echo "  LT_COMMIT_MSG=$LT_COMMIT_MSG"
  echo "  Run logtime-marks to see marks for current sequence"
  echo 
}

logtime-clipboard(){
  source $LT_DIR/clipboard
  printf "%s\n" "${lt_clipboard[@]}"
}

_logtime-meta-restore(){
  local metafile="$LT_DIR/meta/$LT_START.meta"
  echo "Loading: $metafile" >&2
  #eval "$(cat $metafile)"   # loads marks_disposition array
  source $metafile >&2
  echo "Got ${#marks_disposition[@]}" >&2
}

_logtime-meta-save(){
  local metafile="$LT_DIR/meta/$LT_START.meta"
  declare -xp  marks_disposition  > "$metafile"
}

logtime-marks-cat(){
  IFS_ORIG=$IFS
  IFS=$"\n"
  local n=0;
  for line in "${LT_MARKS[@]}"; do
    printf "$line\n"
    (( n++ ))
  done;
  IFS=$IFS_ORIG 
}
logtime-marks(){
  IFS_ORIG=$IFS
  IFS=$"\n"
  local total=0
  local abstime=0
  local n=0
  local start=${1:-0}
  local end=${2:-${#LT_MARKS[@]}}
  _logtime-meta-restore
  lt_clipboard=() 
  for line in "${LT_MARKS[@]}"; do
    IFS=' ' read left right <<< "$line"
    local hms=$(_logtime-hms $left)
    (( abstime=(LT_START + total) ))
    if (( $n >=  "$start"  && $n <= "$end" )); then 
      printf "%3s %5s %-36s  %9s %3s" \
          $n $left "$right" $hms "${marks_disposition[$n]}" 
      printf " %s\n" "$(date +"%a %D %H:%M" -d@$abstime )" 
      lt_clipboard+=("$line")
    fi 
    (( total+=$left ))
    (( n++ ))
  done;
  IFS=$IFS_ORIG
  printf "        Total seconds:%s (%2.2f days)\n" \
      $total $(jq -n "$total/(60*60*24)")
  printf "LT_LASTMARK-LT_START: %s (%2.2f days)\n" \
      $((LT_LASTMARK-LT_START)) $(jq -n "$total/(60*60*24)")
  declare -xp lt_clipboard > $LT_DIR/clipboard
}

logtime-marks-filter(){
  start=${1:-0}
  end=${2:-$LT_MAX_MARKS} # max records is about 32K
  awk "NR > $start && NR <= $end"
}

logtime-marks-copy(){
  local start=${1:-0}
  local end=${2:-${#LT_MARKS[@]}}

}
logtime-help(){
helptext='
Logtime uses Unix date command to create Unix timestamps.
Start with an intention:

  logtime-start working on invoices for logtime

This starts a timer. Mark time by stating what you have 
done while the timer is running:

  logtime-mark "editing logfile.sh"
  logtime-mark "added first draft of instructions"

Get the status by: logtime-status
Restore state: logtime-load <timestamp> # no argument will list all possible
Commit the list of duration marks: logtime-commit  # writes to $LT_TIMELOG
'
  echo "$helptext"
}

#######################################################################
#   Development
#######################################################################
logtime-report-commits(){
  toggle="$(_logtime-make-toggle-html )"

  cat<<EOF
<html>
<head>
<style>
html{
  font-family:tt,courier,monospace;
}
h2{
  margin:0;
}
.nom{
  white-space: pre;
  margin:0;
  display:none;
}
$toggle
</style>
</head>
EOF
_logtime-commits-to-html
  cat<<EOF
</html>
EOF
}

_logtime-make-toggle-html(){
  cat<<EOF
.toggle {
  -webkit-appearance: none;
  -moz-appearance: none;
  appearance: none;
  width: 62px;
  height: 32px;
  display: inline-block;
  position: relative;
  border-radius: 50px;
  overflow: hidden;
  outline: none;
  border: none;
  cursor: pointer;
  background-color: #707070;
  transition: background-color ease 0.3s;
}

.toggle:before {
  content: "on off";
  display: block;
  position: absolute;
  z-index: 2;
  width: 28px;
  height: 28px;
  background: #fff;
  left: 2px;
  top: 2px;
  border-radius: 50%;
  font: 10px/28px Helvetica;
  text-transform: uppercase;
  font-weight: bold;
  text-indent: -22px;
  word-spacing: 37px;
  color: #fff;
  text-shadow: -1px -1px rgba(0,0,0,0.15);
  white-space: nowrap;
  box-shadow: 0 1px 2px rgba(0,0,0,0.2);
  transition: all cubic-bezier(0.3, 1.5, 0.7, 1) 0.3s;
}

.toggle:checked {
  background-color: #4CD964;
}

.toggle:checked:before {
  left: 32px;
}

#seeMore1{
  display: none;
}

#seeMore{
  display: none;
}

#seeMore1:target{
  display: block;
}
EOF

}

_logtime-commits-to-html(){
  local dir=$LT_DIR/commits 
  commits=($(ls $dir))
  for commit in ${commits[@]}; do
    _logtime-commit-to-html $commit
  done
}

_logtime-commit-to-html(){
    commitId=$1
    local commit_dir="$LT_DIR/commits"
    local meta_dir="$LT_DIR/meta"
    # evaluate the stored LT_ARRAY but rename it marks in this shell
    eval $(cat $commit_dir/$commit | grep LT_MARKS | sed s/LT_MARKS/marks/)
    if [ -f "$meta_dir/$commitId.meta" ]; then
       echo "Meta file found for $commitId" >&2
       eval $(cat $meta_dir/$commitId.meta | grep marks_disposition)
    else
       echo "No meta file found for $commitId.$meta" >&2
    fi

    cat <<EOF
<input class="toggle" type="checkbox" />
<h2 style="display:flex">$commitId $(date -d@$commitId) \
<a style="text-decoration:none" href='#$commitId'>
  more
</a>
</h2>
<section  id='seeMore1'class='seeMore' >
  <p>
    Here's some more info that you couldn't see before. I can only be seen after you click the "See more!" button.
  </p>
</section>
EOF

    echo "<div id=\"$commitId\" class=\"nom\">"
      echo -n '<div class="bash-env">'
      cat $commit_dir/$commitId | grep -v LT_MARKS # show below 
      echo "</div> <!-- bash-env -->"
      
      echo -n "<div class='marks'>"
      for i in "${!marks[@]}"; do
        printf "%s" "${marks[$i]}"
        (( pad = 65 - ${#marks[$i]} ))
        #printf "%${pad}s" "${marks[$i]}"
        printf "%${pad}s\n" "${marks_disposition[$i]}"
      done
      echo "</div> <!-- marks -->"

    echo "</div> <!-- nom -->"
}
logtime-mark-undo(){
  local mark=("${LT_MARKS[-1]}")           # last element
  IFS=' ' read first rest <<< "$mark"
  LT_LASTMARK=$(($LT_LASTMARK - $first ))  # roll back when last mark was made
  unset 'LT_MARKS[-1]'                       # leaves a blank line
}

logtime-dev-commit-undo(){
  logtime-load $LT_COMMITS/$_LT_LAST_START   # reload from commit
  LT_STOP=""                                 # by def. must be blank
  rm $LT_COMMITS/$_LT_LAST_START
}

# deals with backup files ID.backup
logtime-dev-delete-state(){
  if [[ -f "$LT_STATES/$LT_START" ]]; then
    mv $LT_STATES/$LT_START* "$LT_TRASH"
    _logtime-clear
  else
    echo "State file $LT_START not found." 
  fi
}

_logtime-dev-parse() {
  while IFS= read -r line; do  #get the whole line, no IFS
      IFS=.; tokens=($line)    # now IFS is .
      local tsHuman=$(date -d@${tokens[0]} 2> /dev/null) 
      if [ ! -z "$tsHuman" ]
      then
        printf '%s\n' "$tsHuman"
        printf '%s\n\n' ${tokens[1]} 
      fi
      IFS=$' \t\n'
  done < "$LT_TIMELOG" 
  IFS=$' \t\n'
}

_logtime-make-line(){
  curline="${LT_MARKS[$1]}"
  (( pad = 65 - ${#curline} ))
  printf "%3s:$curline%${pad}s %s\n" $1 ${marks_disposition[$1]}
}

_logtime-get-marks(){
  total_len=${#LT_MARKS[@]}
  i=${1:-0}
  n=0
  len=${2:-$total_len}

  while (( n < len )) ; do
    _logtime-make-line $i  # just prints, no mutation
    (( n++ )) 
    (( i =(i+1+total_len)%total_len )) 
  done
}
_logtime-get-marks-2(){
  total_len=${#LT_MARKS[@]}
  start=${1:-0}
  len=${2:-$total_len}
  local i=0;
  ((i = start+len   ))
  while ((  len > -2 )) ; do
    _logtime-make-line $i  # just prints, no mutation
    (( len-- )) 
    (( i =(i-1+total_len)%total_len )) 
  done

}
logtime-edit-marks() {
  # this function calls itself, advancing index with arrows
  local contentHeight=10
  _logtime-meta-restore # brings marks_disposition in scope
  cur=${1-0}
  len="${#LT_MARKS[@]}"
  (( cur =(cur+len)%len )) 
  (( start = (cur-contentHeight)%len )) 
  escape_char=$(printf "\u1b") 
  IFS=$'\n'
  local content=( $(_logtime-get-marks $start $contentHeight  ))
 
  local footer=($( 
      printf " \n"
      printf "%s\n" "$(_logtime-make-line $cur)"
      printf " \n"
      printf "plan, active, rest, edit > " 
      ))

  IFS=$' \t\n'
  local headerHeight;
  (( headerHeight =  LINES - ${#content[@]} - ${#footer[@]} -1 ))
  local header=("Logtime marks editor  0.1")
  local n=0; while (( n < $headerHeight )); do header+=(""); (( n++ ));
  done

  prompt="$(
    printf "%s\n" "${header[@]}" 
    printf "%s\n" "${content[@]}" 
    printf "%s\n" "${footer[@]}" 
  )"
  read -p "$prompt" -rsn1 char    # silently get 1 character in restricted mode

  ################## handle arrows ################################
  # https://stackoverflow.com/questions/10679188/casing-arrow-keys-in-bash
  if [[ $char == $escape_char ]]; then                        
    read -rsn2 char # read 2 more chars
  fi 
  case $char in
    '[A') echo; echo;  logtime-edit-marks $((cur - 1 )) ;;
    '[B') echo; echo;  logtime-edit-marks $((cur + 1 )) ;;
    *) 
  esac
  ################## end of handle arrows #########################

  # write marks_disposition ARRAY into 
  # $LT_DIR/meta/1234.meta


  # Should be a case statement off of $char
  if [[ $char != "e" && $char != "" ]]; then

      read -r -p "$char" line   # continue typing

      local curDisp="${marks_disposition[$cur]}";
      [ -z "$curDisp" ] && marks_disposition[$cur]="$char$line"
      [ ! -z "$curDisp" ] && marks_disposition[$cur]=""
      _logtime-meta-save

      _logtime-make-line $cur  # just prints, no mutation
      echo ""
      logtime-edit-marks $(( cur + 1 ))
  fi

  local isFirstInt='^[0-9]*[1-9][0-9]*$'
  if [[ $char == "e" ]]; then
      printf " \n \n"
      read  -i "${LT_MARKS[$cur]}" -e line
      local tokens=($line)
      local delta=${tokens[0]}
      if  [[ "$delta" =~ $isFirstInt &&  "$delta" == "$delta" ]]; then
          sec=$delta
          echo "FOUND NUMBER"
      else
          sec="$(_logtime-hms-to-seconds $delta)"
          echo "FOUND HMS $delta to $sec"
      fi

      IFS=' ' read left right <<< "$line"
      local newline="$sec $right"
      echo "Line: $line"
      echo "newline: $newline"
      
      IFS=$' \t\n'
      LT_MARKS[$cur]="$newline"

      logtime-edit-marks $cur
  fi

  # if first char blank return
  if [[ $char == "" ]]; then
    logtime-edit-marks $(( cur + 1 ))
  fi
  return; 
}

temp(){
  dur=$(_logtime-hms-to-seconds  $1)
  if [ "$dur" -eq 0 ] # 2>/dev/null  # 0 if not an hms string
  then
    dur=$(( $curtime - $LT_LASTMARK ))
    local msg="${@:1}"
  else
    local msg="${@:2}"
  fi
}

_logtime-dev-webserver() {
  while true; do  
    echo -e "HTTP/1.1 200 OK\r\n$(date)\r\n\r\n$(cat $1)" \
          | nc -vl 0.0.0.0:8080; 
  done
}

#marks_disposition=()
test-load(){
  file="$LT_DIR/meta/$LT_START.meta"
  echo "sorcing $file"
  #source "$file"
  #eval "$( cat $file | grep marks_disposition )"
  _logtime-meta-restore
  echo "marks_disposition[0]: " "${marks_disposition[0]}"
}
