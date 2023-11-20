paa_help(){
cat <<EOF
  what ppa?

  paa - prompt-and-answer is a commandline program
  which takes a list of stanzas, each separated by 
  a new line. The first stanza is the prompt, the 
  remaining stanzas are the answer.

  The output is routed to the directory specified 
  in PPA_DATA. If it is not specified, the 
  data is written in the cwd of the shell from 
  which the program was started.

  The output is written as a JSON object with the
  file name prompt-string-with-dashes.

  ex:> ppa < $(ppa-help)
EOF
}

# Define the Bash function to convert a string with spaces to a valid
# Linux file name and print the result
function stanza_to_filename() {
  # Replace all spaces in the input string with dashes
  filename="${1// /-}"

  # Convert the string to lowercase
  #filename="$(sed -E 's/([A-Z])/\L\1/g' <<< "$filename")"
  filename="$(echo "$filename" | tr '[:upper:]' '[:lower:]')"

  printf '%s\n' "$PAA_DATA/$filename"
  return 0

  # Check if the file name is valid and does not already exist
  if test -f "$PAA_DATA/$filename" && ! test -e "$PAA_DATA/$filename"; then
    printf '%s\n' "Invalid file name"
    return -1
  else
    printf '%s\n' "$PAA_DATA/$filename"
    return 0
  fi
}

# Define the Bash function to convert text data to JSON objects and
# write the JSON objects to a file with the name of the "prompt" stanza
function text_to_json() {
  # Initialize a counter for the stanza labels
  stanza_num=0
  unset line;
  line="";
  # Read from standard input (stdin) in a while loop
  while read -r line; do
    # If the line is blank, end the current stanza and start a new one
    if [[ -z $line ]]; then
      # Increment the stanza counter
      ((stanza_num++))

      # Use jq to convert the text stanza to a JSON object,
      # using the appropriate label for the stanza
      if [[ $stanza_num -eq 1 ]]; then
        # Convert the "prompt" stanza to a valid Linux file name
        file_name="$(stanza_to_filename "$stanza")"
        echo "STANZA: $stanza"
        return
        # Use jq to convert the text stanza to a JSON object,
        # and write the JSON object to a file with the name of
        # the "prompt" stanza
        jq -n --arg stanza "$stanza" '{"prompt": $stanza}' > \
          "$PAA_DATA/$file_name.json"
      else
        jq -n --arg stanza "$stanza" \
          --arg num "$stanza_num" '{"s$num": $stanza}' >> \
          "$PAA_DATA/$file_name.json"
      fi
    else
      # Append the current line to the current stanza
      stanza="$stanza\n$line"
    fi
  done
}

