#!/bin/bash

say_info(){
  cat <<EOF
  say.sh: say_voices() reads voice ID strings and greetings from
  stdin line by line and converts those tokens into voice selection
  strings supplied by say -v ?

     n - next
     b - back
     q - quit

  Text is processed according to the Speech Synthesis Markup Language
  available here:

  https://www.ibm.com/docs/en/wvs/6.1.1?topic=610-text-speech-ssml-programming-guide

EOF
}
say_voices() {


   # Read lines into an array
    mapfile -t lines # < "$1"
    local index=0

    while [[ $index -lt ${#lines[@]} ]]; do
    local line=${lines[$index]}
    local voice_name=$(echo "$line" | cut -d' ' -f1)
    local greeting=$(echo "$line" | cut -d'#' -f2 | xargs)
    local locale=$(echo "$line" | grep -oE '[a-z]{2}_[A-Z]{2}')
    local language=$(echo "$locale" | cut -d'_' -f1)
    local country=$(echo "$locale" | cut -d'_' -f2)
    local voice_str="$voice_name"

    # Check if the line has the complex format (with parentheses)
    if [[ "$line" == *"("*")"* ]]; then
      language=$(echo "$line" | awk -F '[()]' '{print $2}' | cut -d' ' -f1)
      country=$(echo "$line" | awk -F '[()]' '{print $3}')
      voice_str="$voice_name ($language ($country))"
    fi

    echo "line: $line"
    echo "voice_name: $voice_name"
    echo "greeting: $greeting"
    echo "locale: $locale"
    echo "language: $language"
    echo "country: $country"
    echo "voice_str: $voice_str"

    # Start 'say' in the background
    say -v "$voice_str" "$greeting" &
         local say_pid=$!

        # User input for navigation
        echo -n "Press 'n' for next, 'b' for back, any other key to stop. "
        read -r -n 1 -s key </dev/tty
        echo

        # Stop the current 'say' process
        kill $say_pid 2>/dev/null
        wait $say_pid 2>/dev/null

        # Navigation logic
        case $key in
            n)
                ((index++))
                ;;
            b)
                if ((index > 0)); then
                    ((index--))
                fi
                ;;
            *)
                echo "Press Enter to continue to the next item, 'q' to quit:"
                read -r -n 1 -s user_input </dev/tty
                if [[ $user_input == 'q' ]]; then
                    break
                fi
                ;;
        esac
    done
}
