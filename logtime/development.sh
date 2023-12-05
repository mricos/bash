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

_logtime-unixtime-to-human(){
  date -d @$1 +'%Y-%m-%d %H:%M:%S'
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

_logtime-dev-commit-undo(){
  logtime-load $LT_COMMITS/$_LT_LAST_START   # reload from commit
  LT_STOP=""                                 # by def. must be blank
  rm $LT_COMMITS/$_LT_LAST_START
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

_logtime-mark-to-raw() {
    while IFS= read -r line; do
        # Read the line into an array
        read -r -a array <<< "$line"
        
        # Extract the relevant fields
        n=${array[0]}
        sec=${array[1]}
        hms=${array[-4]}
        dow=${array[-3]}
        day=${array[-2]}
        time=${array[-1]}
        
        # Combine the tokens for the label_tokens
        label_tokens=()
        for ((i=2; i<${#array[@]}-4; i++)); do
            label_tokens+=("${array[i]}")
        done
        
        echo "${sec} ${label_tokens[*]}"
    done
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
  echo "sourcing $file"
  #source "$file"
  #eval "$( cat $file | grep marks_disposition )"
  _logtime-meta-restore
  echo "marks_disposition[0]: " "${marks_disposition[0]}"
}
