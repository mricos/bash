#!/bin/bash

start_fifo_jq(){
# create named pipe
fifo=/tmp/myfifo
mkfifo $fifo

while true; do
  # generate 1k of random data as JSON
  data=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1000 | head -n 1 | jq -R .)

  # write data to named pipe
  echo "$data" > $fifo
done
}

start_websocat_json() {
  local websocket_server=$1
  local fifo_file=$2
  
  if [[ -p $fifo_file ]]; then
    echo "DELETING FIFO file already exists: $fifo_file"
    rm $fifo_file
  fi
  
  mkfifo $fifo_file
  
  websocat  -s $websocket_server < $fifo_file &

  while true; do
    echo "{\"data\":\"$(head -c 1000 /dev/urandom | base64 | tr -d '\n')\"}" > $fifo_file
    sleep 0.5
  done 
}
