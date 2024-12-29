#!/bin/bash

generate_random_array() {
    local random_values=()
    for i in {1..8}; do
        random_value=$((RANDOM % 256))
        random_values+=($random_value)
    done
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S.%6N')  # Microsecond accuracy timestamp
    echo $(jq -n --arg ts "$timestamp" --argjson rv "$(printf '%s\n' "${random_values[@]}" | jq -R -s -c 'split("\n")[:-1] | map(tonumber)')" '{"timestamp": $ts, "random_values": $rv}')
}

while true; do
    generate_random_array
    sleep 1
done

