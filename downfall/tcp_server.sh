#!/bin/bash

generate_json() {
    while true; do
        RANDOM_VALUE=$(od -An -N2 -i /dev/random | tr -d ' ')
        echo $(jq -n --arg rv "$RANDOM_VALUE" '{"random": $rv}')
        sleep 1
    done
}

serve_dataOld() {
    socat TCP4-LISTEN:8081,fork EXEC:'generate_json'
}

#!/bin/bash

serve_data() {
    socat TCP4-LISTEN:8081,fork EXEC:'bash -c "while true; do RANDOM_VALUE=\$(od -An -N2 -i /dev/random | tr -d \\" \\"); echo \$(jq -n --arg rv \"\$RANDOM_VALUE\" \\"{\\\\\\"random\\\\\\": \\\$rv}\\"); sleep 1; done"'
}

serve_data

#generate_json & serve_data

