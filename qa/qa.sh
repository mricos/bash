#!/bin/bash

#source $(dirname $BASH_SOURCE)/src/formatting.sh
# Directory for storing data and configurations
QA_SRC="$HOME/src/mricos/bash/qa/qa.sh"
QA_DIR="$HOME/.qa"
alias qq='qa_query'
alias q1='_QA_ENGINE=gpt-3.5-turbo; qa_query'
alias q2='_QA_ENGINE=gpt-4-turbo; qa_query'
alias q3='_QA_ENGINE=gpt-4o-mini; qa_query'
alias db="ls $QA_DIR/db"

# Default configurations overwriten by init()
_QA_ENGINE="gpt-3.5-turbo"             # Default engine
_QA_ENGINE_ALT="gpt-4-turbo"           # Default alt engine
_QA_CONTEXT="Write smart, dry answers" # Example default context

_QA_ENGINE_FILE="$QA_DIR/engine"
_QA_CONTEXT_FILE="$QA_DIR/context"
_OPENAI_API_FILE="$QA_DIR/api_key"

_qa_sanitize_index ()
{
    local index=$1
    if [[ -z "$index" ]]; then
	     index=0
    fi
    echo "$index"
}

_qa_sanitize_input()
{
    local input=$1
    # 1. Remove leading and trailing whitespace
    input=$(echo "$input" | awk '{$1=$1};1')

    # 2. Remove non-printable characters
    input=$(echo "$input" | tr -cd '[:print:]')

    # 3. Escape special characters
    #   Note: This is not a complete list of special characters
    input=$(echo "$input" | sed -e 's/"/\\\\"/g')

    # 4. Replace line breaks with \n
    # input=$(echo "$input" | tr '\\n' ' ')
    input=$(echo "$input" | tr '\n' ' ')

    # 5. Additional custom sanitation can be added here
    echo "$input"
}


qa_test(){
  qq what is the fastest land animal?
  a
}

qa_query ()
{
    echo "Using $_QA_ENGINE" >&2
    local api_endpoint="https://api.openai.com/v1/chat/completions"
    local db="$QA_DIR/db"
    local id=$(date +%s)
    if [ ! -z "$1" ]; then
        local input="$@"
    else
        echo "Enter your query, press Ctrl-D when done:" >&2
        local input=$(cat)  # Read entire input as-is 
        echo "Processing your query..." >&2
    fi

    echo "$input" > "$db/$id.prompt"
    input=$(_qa_sanitize_input "$input")
    local data
    data=$(jq -nc --arg model "$_QA_ENGINE" \
                   --arg content "$input" \
   '{
     model: $model,
     messages: [ {
                   role: "user",
                   content: $content
                 }
               ]
   }')

   echo "$data" > "$db/$id.data"

    # Construct curl command using an array
    local curl_cmd=(
        curl -s --connect-timeout 10 -X POST "$api_endpoint"
        -H "Authorization: Bearer $_OPENAI_API"
        -H "Content-Type: application/json" -d "$data"
    )

    local response
    response=$("${curl_cmd[@]}")

    if [ $? -ne 0 ]; then
        echo "Curl command failed. Check the API endpoint cconnection."
        return 1
    fi

    echo "$response" > "$db/$id.response"
    local answer=$(echo "$response" | jq -r '.choices[0].message.content')

    if [[ -z "$answer" || "$answer" == "null" ]]; then
        "No valid answer received or response is null."  > "$db/$id.answer"
        return 1
    fi

    echo "$answer" > "$db/$id.answer"
    ln -sf "$db/$id.answer" "$QA_DIR/last_answer"

    # If cli was not empty then we are answering 
    # a short question so print it out.
    # Multiline responses do not print automatically.
    [ ! -z "$1" ] && echo "$answer"
    
} 

# Show documentation
qa_help() {
    cat <<EOF
Q&A Command Line Tool Documentation:
------------------------------------
qa_docs          - Show this documentation.
qa_status        - Display current system status.
qa_set_apikey    - Set the API key for the Q&A engine.
qa_set_engine    - Set the Q&A engine (default: OpenAI).
qa_set_context   - Set default context for queries.
qa_select_engine - Select the engine from available OpenAI engines.
q                - Query with detailed output
a                - Most recent answer
as               - All answers

EOF
}

# Display current system status
qa_status() {
    echo "API Key file: $_OPENAI_API_FILE"
    echo "API Key: $(cat $_OPENAI_API_FILE)"
    echo "Engine: $(cat $_QA_ENGINE_FILE)"
    echo "Context: $(cat $_QA_CONTEXT_FILE)"
}

# Set the API key for the Q&A engine
qa_set_apikey() {
    _OPENAI_API="$1"
    echo "$_OPENAI_API" > "$_OPENAI_API_FILE"
}

# Set the Q&A engine (default: OpenAI)
qa_set_engine() {
    _QA_ENGINE="$1"
    echo "$_QA_ENGINE" > "$_QA_ENGINE_FILE"
}

# Set default context for queries
qa_set_context() {
    _QA_CONTEXT="$1"
    echo "$_QA_CONTEXT" > "$_QA_CONTEXT_FILE"
}

# List and select an engine from OpenAI's available engines
qa_select_engine() {
    local engines=$(curl -s \
      -H "Authorization: Bearer $_OPENAI_API" \
      "https://api.openai.com/v1/engines")

    echo "Available Engines:"
    echo "$engines" | jq -r '.data[].id'

    echo "Enter the engine you want to use: "
    read selected_engine

    # Validate if the selected engine is in the list
    if echo "$engines" | jq -r '.data[].id' | \
        grep -qx "$selected_engine"; then
        qa_set_engine "$selected_engine"
    else
        echo "Invalid engine selected."
    fi
}

# Initialize system
qa_init() {

    # Ensure the db directory exists
    mkdir -p "$QA_DIR/db"       # all queries and responses

    if [ -f "$_OPENAI_API_FILE" ]; then
       _OPENAI_API=$(cat "$_OPENAI_API_FILE")
    fi
    if [ -f "$_QA_ENGINE_FILE" ]; then
        _QA_ENGINE=$(cat "$_QA_ENGINE_FILE")
    fi
    if [ -f "$_QA_CONTEXT_FILE" ]; then
        _QA_CONTEXT=$(cat "$_QA_CONTEXT_FILE")
    fi
    qa_set_context "$_QA_CONTEXT"  # Set initial context
}


qa_id() {
    local file="$1"
    if [[ -L "$file" ]]; then
        file=$(readlink -f "$file")
    fi
    local filename=$(basename "$file")
    local id=$(echo "$filename" | cut -d '.' -f 1)
    echo "$id"
}


q()
{
    # get the last question
    local db="$QA_DIR/db"
    local files=($(ls $db/*.prompt | sort -n))
    local last=$((${#files[@]}-1))
    local indexFromLast=$(_qa_sanitize_index $1)
    local index=$(($last-$indexFromLast))
    cat "${files[$index]}"
}

qa_delete(){
    local files=($(ls $db/*.answer | sort -n))
    local last=$((${#files[@]}-1))
    local indexFromLast=$(_qa_sanitize_index $1)
    local index=$(($last-$indexFromLast))
    echo "${files[$index]}"
}

a()
{
    # get the last answer
    local db="$QA_DIR/db"
    local files=($(ls $db/*.answer | sort -n))
    local last=$((${#files[@]}-1))
    local indexFromLast=$(_qa_sanitize_index $1)
    local index=$(($last-$indexFromLast))
    cat "${files[$index]}"
    ln -sf "${files[$index]}" "$QA_DIR/last_answer"
}

qa_responses ()
{
    local db="$QA_DIR/db"
    local listing=$(ls -1 "$db"/*.response)
    local filenames=""
    readarray -t filenames <<< "$listing"
    for i in "${!filenames[@]}"
    do
        local msg=$(head -n 1 "${filenames[$i]}")
        echo "$((i+1))) ${filenames[$i]}: $msg"
    done
}

qa_db_nuke(){
	 # check if the user is sure
    read -p "Delete all queries and responses? [y/N] " -n 1 -r
    local db="$QA_DIR/db"
    rm -rf "$db"
    mkdir -p "$db"
    echo ""
}


fa() {
    # Set default values for parameters, allowing overrides
    local lookback=${1:-0}
    local width=${2:-$((COLUMNS - 8 ))}
    a $lookback | glow --pager -s dark -w "$width"
}

# refactor to use  _get_file
# should take lookback
# if narg = 1, lookback=0, grade=$1
# if narg = 2, lookback=$1, grade=$2
ga(){
    local lookback=${1:-0}
    local grade=${2:-0}
    local db="$QA_DIR/db"
    local files=($(ls $db/*.answer | sort -n))
    local last=$((${#files[@]}-1))
    local indexFromLast=$(_qa_sanitize_index $lookback)
    local index=$(($last-$indexFromLast))
    echo  $grade >"${files[$index]}.grade"
    #echo ${files[$index]}.grade
}

qa_export() {
    for var in $(compgen -A variable QA); do
        export $var
    done
    
    for var in $(compgen -A variable _QA); do
        export $var
    done
    for func in $(compgen -A function qa); do
        export -f $func
    done
    
    for func in $(compgen -A function _qa); do
        export -f $func
    done
}

qa_init
qa_export
