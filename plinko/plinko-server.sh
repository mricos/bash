#!/usr/bin/env bash

plinko-start(){
  plinko-server &
  plinkopid=$!
  echo "Pid: $plinkopid"
  echo "$plinkopid" > plinko.pid
}

plinko-kill(){
  kill -- -$(cat plinko.pid)
  rm plinko.pid
}

plinko-server(){
while { echo -en "$RESPONSE"; } | \
        exec -a "plinko-server" nc -l "${1:-8080}"; do
  RESPONSE="HTTP/1.1 200 OK\r\n\
  Connection: keep-alive\r\n\r\n\
  $(cat plinko.html)\
  \r\n"
done
}
