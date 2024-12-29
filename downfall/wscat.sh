#!/bin/bash

# Generate 1000 bytes of random data and convert to base64
RANDOM_DATA=$(head -c 1000 /dev/random | base64)

# Wrap the base64-encoded data in a JSON object
JSON_DATA=$(echo $RANDOM_DATA | jq -Rs '{data: .}')

# Send the data to the WebSocket server using wscat
echo $JSON_DATA  | websocat -s 8080 

