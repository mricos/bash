#!/bin/bash
#source $(dirname $BASH_SOURCE)/src/formatting.sh
# Directory for storing logs and configurations
QA_DIR="$HOME/.qa"
alias q='qa_query'
alias qq='qa_query'
alias db="ls $QA_DIR/db"

# Default configurations overwriten by init()
_QA_ENGINE="gpt-3.5-turbo"         # Default engine
_QA_ENGINE_ALT="gpt-4-turbo"         # Default engine
QA_CONTEXT="Two sentences only."  # Example default context

_QA_ENGINE_FILE="$QA_DIR/engine"
_QA_CONTEXT_FILE="$QA_DIR/context"
_OPENAI_API_FILE="$QA_DIR/api_key"


qa_test(){
  q what is the fastest land animal?
  a
}

alias qqb="qa_query_alt"
qa_query_alt(){
    local orig="$_QA_ENGINE";
    _QA_ENGINE=$_QA_ENGINE_ALT
    qa_query "$@"
    _QA_ENGINE="$orig"
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
        echo "Enter your query, press Ctrl-D when done:"
        local input=$(cat)  # Read entire input as-is
        echo "Processing your query..."
    fi

    echo "$input" > "$db/$id.prompt"
    input=$(_qa_sanitize_input "$input")
    local data
    data=$(jq -nc --arg model "$_QA_ENGINE" \
                   --arg content "$input" \
   '{model: $model, messages: [{role: "user", content: $content}]}')
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
    input=$(echo "$input" | tr '\\n' ' ')

    # 5. Additional custom sanitation can be added here
    echo "$input"
}

qa_escape_newlines() {
    awk '{ printf "%s\\n", $0 }' | tr -d '\n'
}

qa_unescape_newlines() {
    while IFS= read -r line; do printf '%b\n' "$line"; done
}

# Show documentation
qa_docs() {
    cat <<EOF
Q&A Command Line Tool Documentation:
------------------------------------
qa_docs          - Show this documentation.
qa_status        - Display current system status.
qa_set_apikey    - Set the API key for the Q&A engine.
qa_set_engine    - Set the Q&A engine (default: OpenAI).
qa_set_context   - Set default context for queries.
qa_select_engine - Select the engine from available OpenAI engines.
qa_reset         - Resets history in $QA_DIR (~/.qa by default)
qa_log           - Log a message to the log $QA_DIR/qa.log
qa_log_show      - Show debug log
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

# Function to list and select an engine from OpenAI's available engines
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
    qa_set_context "$_QA_CONTEXT"  # Log initial context
}

qa_reset() {
    # Reset function to clear out answers.json and last_answer
    > "$QA_DIR/answers.json"  # Clear the answers.json file
    > "$QA_DIR/last_answer"   # Clear the last_answer file
    echo "Reset complete: answers.json and last_answer have been cleared."
}

MAX_LOG_LINES=1000

qa_log() {
    local message="$@"
    _QA_LOG=$QA_DIR/qa.log
    # Append new message with timestamp to the log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$_QA_LOG"

    # Trim the log file to keep only the last MAX_LOG_LINES lines
    # This creates a temporary file to hold the trimmed content
    tail -n $MAX_LOG_LINES "$_QA_LOG" > "$_QA_LOG.tmp"
    mv "$_QA_LOG.tmp" "$_QA_LOG"
}

qa_log_show(){
   cat $_QA_LOG
}

_qa_validate_input ()
{
    local index=$1
    local array_length=$2

    if [[ -z "$index" ]] ||   # Check if index is empty
       [[ ! "$index" =~ ^-?[0-9]+$ ]] ||   # Check if index is not a number
       [[ "$index" -lt 0 ]] ||   # Check if index is negative
       [[ "$index" -ge "$array_length" ]];   # Check if index is out of range
    then
        echo "Invalid index"
        return 1
    fi

    return 0
}

qa_file_to_id() {
    local file="$1"
    if [[ -L "$file" ]]; then
        file=$(readlink -f "$file")
    fi
    local filename=$(basename "$file")
    local id=$(echo "$filename" | cut -d '.' -f 1)
    echo "$id"
}


a ()
{
    # get the last answer
    local db="$QA_DIR/db"
    local files=($(ls $db/*.answer | sort -n))
    local last=$((${#files[@]}-1))
    local indexFromLast=$(_qa_sanitize_index $1)
    local index=$(($last-$indexFromLast))
    cat "${files[$index]}"
}

_qa_sanitize_index ()
{
    local index=$1
    if [[ -z "$index" ]]; then
	     index=0
    fi
    echo "$index"
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

qa_init

#> FORMATTING

QA_MARGIN=${QA_MARGIN:-auto}
QA_SPACING=${QA_SPACING:-1}
QA_TOP=${QA_TOP:-2}
QA_BOTTOM=${QA_BOTTOM:-3}
QA_WIDTH=${QA_WIDTH:-65}


fa_init() {
    QA_MARGIN=auto
    QA_SPACING=1
    QA_TOP=2
    QA_BOTTOM=3
QA_WIDTH=65
}

fa_env(){
    echo "QA_MARGIN=$QA_MARGIN"
    echo "QA_SPACING=$QA_SPACING"
    echo "QA_TOP=$QA_TOP"
    echo "QA_BOTTOM=$QA_BOTTOM"
    echo "QA_WIDTH=$QA_WIDTH"
}
fa() 
{ 
    local lookback=${1:-0}
    local width=${2:-$QA_WIDTH}
    local margin=${3:-$QA_MARGIN}
    local spacing=${4:-$QA_SPACING}
    local top=${5:-$QA_TOP}
    local bottom=${6:-$QA_BOTTOM}

    # margin provided parameter, auto if not set
    if [ "$margin" = "auto" ] || [ -z "$margin" ]; then
        margin=$(( ($COLUMNS - $width) / 2 ))
    fi

    MARGIN=$(printf '%*s' "$margin" '')

    a $lookback | glow -s dark -w $width | \
    awk \
    -v margin="$MARGIN" \
    -v spacing="$spacing" \
    -v top="$top" \
    -v bottom="$bottom" \
    '
    BEGIN {
        for (i = 0; i < top; i++) print margin
    }
    {
        print margin $0
        if (NR < NF) {
            for (i = 0; i < spacing-1; i++) print margin
        }
    }
    END {
        for (i = 0; i < bottom; i++) print margin
    }
    ' | less -R
}
