#!/bin/bash

# start lighttpd
lighttpd -D -f <(echo "
    server.document-root = \"$(pwd)/public\"
    server.port = 8080
    mimetype.assign = (
        \".html\" => \"text/html\",
        \".js\" => \"application/javascript\",
        \".css\" => \"text/css\",
        \".json\" => \"application/json\",
        \".png\" => \"image/png\",
        \".jpg\" => \"image/jpeg\",
        \".gif\" => \"image/gif\",
    )
")

# generate random JSON data and send it to the websocket
while true; do
    data=$(cat /dev/random \
            | base64 \
            | head -c 1024 \
            | jq -R -s 'split("\n") | map(select(length > 0))'
    )

    data2=$(
          </dev/random \
          tr -dc '[:alnum:]' \
          | head -c1000 \
          | sed 's/.*/{"data": "&"}/' \
          | while read -r line; do
              echo "$line"
              sleep 0.5
            done
    )


    echo "$data" | websocat ws://localhost:8080/ws
    sleep 0.5
done

