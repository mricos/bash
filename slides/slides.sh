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
  export slides_deck=$1
  execute_str="bash -c \"source ./slides.sh; slides-start $slides_deck; bash\""
  export XDG_CONFIG_HOME="./config"; \
  #xfce4-terminal --disable-server \
  xfce4-terminal --disable-server
  slides_viewer_pid=$!
  #-e '"cat > "' 
  #-e 'bash -c "source ./slides.sh; cat << "' 
  #-e "$execute_str"
}

slides-load(){
  #shopt -s nullglob
  export slides_deck=$1
  export slides=( $slides_deck/* )
  export slides_cur=0
  export slides_total=${#slides[@]}
  printf 'Got %s slides: \n'  $slides_total
  printf '%s \n' "${slides[@]}"
}

slides-start(){
  slides-load $1
  slides-render 0
}

slides-render(){
  echo Got render looking for ${slides[1]}
  echo With slides_deck =  $slides_deck
  echo And slides =  ${slides[@]}
  cat ${slides[$1]}
}

slides-loop(){
  ITER=0
  for I in ${slides[@]}
  do  
    echo ${I} ${ITER}
    ITER=$(expr $ITER + 1)
    cat ${slides[$ITER]}
  done
}

slides-next(){
  #echo "Slide $slides_cur"
  (( slides_cur++ ))
  (( slides_cur = slides_cur % $slides_total))
  slides-render $slides_cur
  sleep .1
  slides-next
}
