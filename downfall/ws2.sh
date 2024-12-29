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
#    websocat -t -u ws-l:127.0.0.1:8080 sh-c:'generate_json'
        websocat -t -u ws-l:127.0.0.1:8080 sh-c:'while true; do RANDOM_VALUE=$(od -An -N2 -i /dev/random | tr -d " "); echo $(jq -n --arg rv "$RANDOM_VALUE" "{\"random\": \$rv}"); sleep 1; done'

}

# Run the serve_data function
serve_data

