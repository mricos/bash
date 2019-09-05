slides-help(){
  echo "  
   slides is a command line program from making slides in a terminal.
   Currently xfce4-terminal is supported.
  "
}

slides-viewer(){
  # XDG_ — based on standard at: specifications.freedesktop.org
  # xfce4-terminal has only one entry point XDG_CONFIG_HOME
  # and config file must be in $XDG_CONFIG_HOME/xfce4/terminal/terminalrc

  #execute_str="bash -c \"tty; ps; cat >&0\""
  #execute_str="bash -c \"cat >&0\""
  #execute_str="/bin/env ./slide-viewer.sh"
  #execute_str="env -i bash --norc --noprofile"
  #execute_str="env -i bash --rcfile ./slide-viewer.sh --noprofile"

  export XDG_CONFIG_HOME="./config"

  xfce4-terminal --disable-server \
  -x /usr/bin/env bash --noprofile --rcfile ./slide-viewer.sh &
  
  terminalrc=$XDG_CONFIG_HOME/xfce4/terminal/terminalrc
  cat $terminalrc
}

slides-xfce-reset(){
  cp "$terminalrc.orig" "$terminalrc"
}

slides-xfce(){
  local newrc="$terminalrc.new"
  echo "creating $newrc"
  cat /dev/null > $newrc
  while IFS='' read -r line || [[ -n "$line" ]]; do
     IFS== read left right <<< "$line"
     if [ "$left" == "$1" ]
     then
       echo "$left=$2" >> $newrc
       echo "$left=$2" 
     else
       echo "$line" >> $newrc
       echo "$line" 
     fi
  done < "$terminalrc"

  cp $terminalrc "$terminalrc.old"
  cp $newrc "$terminalrc"
}

slides-load(){
  shopt -s nullglob
  #slides_tty=$(tty)
  slides_tty=$(cat ./viewer-tty)
  slides_deck=$1
  slides_deltatime=.5
  slides=( $slides_deck/* )
  slides_cur=0
  slides_total=${#slides[@]}
  printf 'Got %s slides: \n'  $slides_total
  printf '%s \n' "${slides[@]}"
}

slides-start(){
  slides-render 0
}

slides-render(){
  local curslide="${slides[$1]}"
  echo Got render looking for ${slides[$1]} >&2
  echo With slides_deck =  $slides_deck  >&2 
  echo And slides =  ${slides[@]} >&2
  numLines=$(wc -l < $curslide)
  echo NumLines: $numLines >&2
  local topmargin=$(( (12 - numLines)/2 ))
  echo "top=$topmargin" >&2
  for((i=1;i<=$topmargin;i++)); do echo ""; done
  while read p; do
    local linelen=${#p}
    local leftmargin=$((20 - linelen/2))
    for((i=1;i<=$leftmargin;i++)); do printf " "; done
    printf '%s\n' "$p"
  done <$curslide
  for((i=1;i<=$topmargin;i++)); do echo ""; done
}

slides-loop() {
  ITER=0;
  while true; do
    local deltatime=$(cat speed)
    modulo=$ITER%3
    ITER=$(expr $ITER + 1)
    #cat ${slides[$modulo]}
    slides-render $modulo
    sleep $deltatime
  done
}

slides-metronome() {
  local n=0; 
  local bpm=120;
  local secPerBeat=.5;

  while true; do
    local =$(cat bpm)
    modulo=$n%3
  done
}

slides-next(){
  local deltatime=$1
  echo "Slide $slides_cur with deltatime=$deltatime" >&2
  (( slides_cur++ ))
  (( slides_cur = slides_cur % $slides_total))
  slides-render $slides_cur
  sleep $deltatime 
  slides-next $deltatime
}
