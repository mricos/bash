#!/bin/bash

# generate random JSON data and send it to the websocket
while true; do
    # Generate 1000 bytes of random data and convert to base64
    random_data=$(head -c 1000 /dev/random | base64)
    # Wrap the base64-encoded data in a JSON object
    json_data=$(echo $random_data | jq -Rs '{data: .}')
    echo $json_data | websocat -s 8080
    sleep 0.5
done

#!/bin/bash

# Generate 1000 bytes of random data and convert to base64
#RANDOM_DATA=$(head -c 1000 /dev/random | base64)

# Wrap the base64-encoded data in a JSON object
#JSON_DATA=$(echo $RANDOM_DATA | jq -Rs '{data: .}')

# Send the data to the WebSocket server using wscat
#echo $JSON_DATA  | websocat -s 8080 

