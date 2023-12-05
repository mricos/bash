#######################################################################
#  Helper functions start with _ 
#######################################################################

_logtime-clear(){
  LT_START=""             # set at creation 
  LT_STOP=""              # empty until commit
  LT_MSG=""               # set at creation
  LT_LASTMARK=$(date +%s) # timestamp
  LT_MARKS=()             # array of strings; duration in seconds
}

_logtime-append(){
  # 7200 summary text
  local src=$1
  while read line
  do
    LT_MARKS+=( "$line" );
    # printf "pushed to LT_MARKS: %s\n" "$line"
  done < $src
}

_logtime-delete(){
  local file=$LT_DIR/states/$1
  if [ -f "$file" ]; then
    echo "Deleting $file <ret> to continue"
    read
    mkdir -p /tmp/logtime
    cp $file "/tmp/logtime/$file.$(date +%s)"
    rm $file
  else
    echo "$file file not found"
  fi 
}

_logtime-show(){
  local -n var=$1
  for line in "${var[@]}"; do
    echo "$line"
  done
}

_logtime-save(){
  if [ -z $LT_START ]; then
    echo "LT_START is empty. Use logtime-start [offset] [message]."
  else
    local outfile=$LT_DIR/states/$LT_START
    local backup=$LT_DIR/backup/$LT_START.backup
    if [ -f "$outfile" ]; then            # first time outfile does not exist
      cp  $outfile $backup                # otherwise overwrite the backup
    fi
    export ${!LT_@}
    declare -xp  ${!LT_@}  > "$outfile"
    if [ $? -eq 0 ]; then
      printf '%s\n' "Wrote to $outfile"
    fi
  fi
}
_logtime-load-interactive(){
  local type=${1:-states} 
  _logtime-objects "$LT_DIR/$type" 
  local listing=$(ls -1 "$LT_DIR/$type")
  local filenames=""
  readarray -t filenames <<< "$listing";
  read -p "Select $type to load: " filenum 
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
  LT_START_MSG=""
  LT_MSG=""
  _logtime-source "$1";
  echo "$LT_MSG$LT_START_MSG"
}

_logtime-objects() {
  local dir=$1 # have to provide dir
  local listing=$(ls -1 "$dir")
  local filenames=""
  readarray -t filenames <<< "$listing";
 for i in "${!filenames[@]}"  #0 indexing ${!varname[@]} returns indices
  do
    local msg=$(_logtime-get-startmsg "$dir/${filenames[$i]}")  
    echo "$((i+1))) ${filenames[$i]}: $msg"
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

_logtime-marks-compare() {
    local -n array1=$1
    local -n array2=$2

    # Make sure the arrays have the same length
    if [[ ${#array1[@]} -ne ${#array2[@]} ]]; then
        echo "Arrays have different lengths"
        return 1
    fi

    # Compare elements
    for index in "${!array1[@]}"; do
        if [[ "${array1[index]}" != "${array2[index]}" ]]; then
            echo "Difference at index $index: ${array1[index]} vs ${array2[index]}"
            #return 1
        else
            echo "Same at index $index: ${array1[index]} vs ${array2[index]}"
        fi
    done

    #echo "Arrays are identical"
    return 0
}

_logtime-meta-restore(){
  local metafile="$LT_DIR/meta/$LT_START.meta"
  if [ -f "$metafile" ]
  then
     echo "Using: $metafile"
     #eval "$(cat $metafile)"   # loads marks_disposition array
     source $metafile >&2
  else
     echo "File not found: $metafile" > /dev/null
  fi

  #echo "Got ${#marks_disposition[@]}" >&2
}

_logtime-meta-save(){
  local metafile="$LT_DIR/meta/$LT_START.meta"
  declare -xp  marks_disposition  > "$metafile"
}

