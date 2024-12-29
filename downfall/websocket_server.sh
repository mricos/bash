#!/bin/bash

# Fill a fifo with json data using /dev/random and jq
generate_json() {
    while true; do
        RANDOM_VALUE=$(od -An -N2 -i /dev/random | tr -d ' ')
        jq -n --arg rv "$RANDOM_VALUE" '{"random": $rv}' > json_pipe
        sleep 1
    done
}

# Serve randomly generated data using WebSocat
serve_data() {
    websocat -t -u ws-l:127.0.0.1:8080 dio:json_pipe
}

# Create the named pipe before running the functions
rm json_pipe
mkfifo json_pipe

# Run both functions concurrently
generate_json & serve_data & wait
