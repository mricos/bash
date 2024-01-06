#d!/bin/bash

# Directory for storing logs and configurations
QA_DIR="$HOME/.qa"
mkdir -p "$QA_DIR"

# Default configurations overwriten by init()
QA_ENGINE="gpt-3.5-turbo"  # Default engine
QA_CONTEXT="Two sentences only."  # Example default context

_QA_ENGINE_FILE="$QA_DIR/engine"
_QA_CONTEXT_FILE="$QA_DIR/context"
_OPENAI_API_FILE="$QA_DIR/api_key"

qa_test(){
  q what is the fastest land animal?
  a
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
    OPENAI_API="$1"
    echo "$OPENAI_API" > "$_OPENAI_API_FILE"
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
      -H "Authorization: Bearer $OPENAI_API" \
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

q ()
{
    local input="";
    local error_output="$QA_DIR/error.log";
    local api_endpoint="<https://api.openai.com/v1/chat/completions>";
    local data response answer json_entry;
    if [[ -n "$1" ]]; then
        input="$1";
    else
        echo "Enter your query, press Ctrl-D when done.";
        while IFS= read -r line; do
            input+="$line\\n";
        done;
    fi;
    if [[ -z "$input" ]]; then
        echo "No input received, exiting.";
        return 1;
    fi;
    echo "Processing your query...";
    qa_debug "Sending query: $input";
    data=$(jq -nc --arg model $(<$_QA_ENGINE_FILE) --arg content "$input"
        '{model: $model, messages: [{role: "user", content: $content}]}');
    qa_debug "Formulated data: $data";
    response=$(curl -s --connect-timeout 10 -X POST "$api_endpoint"
        -H "Authorization: Bearer $(<$_OPENAI_API_FILE)"
        -H "Content-Type: application/json" -d "$data"
        2>> "$error_output");
    qa_debug "Full response: $response";
    answer=$(echo "$response" | jq -r '.choices[0].message.content');
    if [[ -z "$answer" || "$answer" == "null" ]]; then
        qa_debug "No valid answer received or response is null.";
        return 1;
    fi;
    echo "$answer" > "$QA_DIR/last_answer";
    echo "$input" >> "$QA_DIR/query_log";
    echo "$answer" >> "$QA_DIR/answer_log";
    json_entry=$(jq -nc --arg query_delta "$input" --arg answer "$answer"
        '{query_delta: $query_delta, answer: $answer}');
    echo "$json_entry" >> "$QA_DIR/answers.json";
    qa_debug "Answer: $answer";
    echo -e "Your query:\\n$input\\n\\nAnswer:\\n$answer"
}


# Initialize system
qa_init() {
    if [ -f "$_OPENAI_API_FILE" ]; then
        OPENAI_API=$(cat "$_OPENAI_API_FILE")
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
    local message=$1
    _QA_LOG=$QA_DIR/qa.log
    # Append new message with timestamp to the log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$_QA_LOG"

    # Trim the log file to keep only the last MAX_LOG_LINES lines
    # This creates a temporary file to hold the trimmed content
    tail -n $MAX_LOG_LINES "$_QA_LOG" > "$_QA_LOG.tmp"
    mv "$_QA_LOG.tmp" "$_QA_LOG"
}

qa_debug(){
   true && qa_log "[debug] $@"
}

qa_log_show(){
   cat $_QA_LOG
}

a ()
{
    cat "$QA_DIR/last_answer"
}

as() {
    cat "$QA_DIR/answer_log"
}

aj(){
    cat "$QA_DIR/answers.json"
}

# Main
qa_init
