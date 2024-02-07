logtime-init(){
  local dir=$HOME/.logtime
  mkdir $dir
  mkdir $dir/states
  mkdir $dir/commits
  mkdir $dir/store
  mkdir $dir/clipboard # deprecated 
  mkdir $dir/stack     # deprecated
  
  sudo apt install jq
}

