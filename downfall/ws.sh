#!/bin/bash

# Fill a fifo with json data using /dev/random and jq
generate_json() {
    while true; do
        RANDOM_VALUE=$(od -An -N2 -i /dev/random | tr -d ' ')
        echo $(jq -n --arg rv "$RANDOM_VALUE" '{"random": $rv}')
        sleep 1
    done
}


# Serve randomly generated data using WebSocat
serve_data() {
    websocat -t -u ws-l:127.0.0.1:8080 -
}

# Run both functions concurrently, and send data from generate_json to serve_data using a pipe
generate_json | serve_data

