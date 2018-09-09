#usage: map fn arrayname
p-map(){                                  
  local -n arr=$2               #allows index syntax in for loop
  for i in "${arr[@]}"; do
    $1 $i 
  done
}

p-reduce(){
  nextfile="/tmp/next-reduce-001"
  totalfile="/tmp/total-reduce-001"
  tmpfile="/tmp/tmp-reduce-001"
  cat /dev/null > $tmpfile
  cat /dev/null > $totalfile
  cmd=$1
  local -n arr=$2               #allows index syntax in for loop
  echo "Reducer: $cmd $tmpfile $nextfile > $totalfile"

  for i in "${arr[@]}"; do
    echo $i > $nextfile
    cat $totalfile > $tmpfile
    $cmd $tmpfile $nextfile > $totalfile
  done
  echo "Contents of total reduce:  $totalfile:"
  cat $totalfile
}
