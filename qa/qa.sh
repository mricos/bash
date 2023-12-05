#!/bin/bash

# Directory for storing logs and configurations
QA_DIR="$HOME/.qa"
mkdir -p "$QA_DIR"

# Default configurations
QA_ENGINE="gpt-3.5-turbo"  # Default engine
QA_CONTEXT="Two sentences only."  # Example default context
OPENAI_API=""  # Set your OpenAI API key here if you have one

QA_ENGINE_FILE="$QA_DIR/engine"
QA_CONTEXT_FILE="$QA_DIR/context"
OPENAI_API_FILE="$QA_DIR/api_key"

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
    echo "API Key: $(cat $OPENAI_API_FILE)"
    echo "Engine: $(cat $QA_ENGINE_FILE)"
    echo "Context: $(cat $QA_CONTEXT_FILE)"
}

# Set the API key for the Q&A engine
qa_set_apikey() {
    OPENAI_API="$1"
    echo "$OPENAI_API" > "$OPENAI_API_FILE"
}

# Set the Q&A engine (default: OpenAI)
qa_set_engine() {
    QA_ENGINE="$1"
    echo "$QA_ENGINE" > "$QA_ENGINE_FILE"
}

# Set default context for queries
qa_set_context() {
    QA_CONTEXT="$1"
    echo "$QA_CONTEXT" > "$QA_CONTEXT_FILE"
}

# Function to list and select an engine from OpenAI's available engines
qa_select_engine() {

    local engines=$(curl -s \
      -H "Authorization: Bearer $(cat $OPENAI_API_FILE)" \
      "https://api.openai.com/v1/engines")

    echo "Available Engines:"
    echo "$engines" | jq -r '.data[].id'

    echo "Enter the engine you want to use: "
    read selected_engine

    # Validate if the selected engine is in the list
    if echo "$engines" | jq -r '.data[].id' | grep -qx "$selected_engine"; then
        qa_set_engine "$selected_engine"
    else
        echo "Invalid engine selected."
    fi
}

q() {
    local context=$(cat $QA_CONTEXT_FILE)
    local query_delta="${*}"
    local debug_output="$QA_DIR/debug"

    # Start writing to the debug file
    qa_debug "Sending query: $context $query_delta" 

    local data=$(jq -nc \
      --arg model $(cat $QA_ENGINE_FILE) \
      --arg content "$context $query_delta" \
     '{model: $model, messages: [{role: "user", content: $content}]}')

    qa_debug "Formulated data: $data"

    local response=$(curl -v -s \
        --connect-timeout 10 \
        -X POST "https://api.openai.com/v1/chat/completions" \
                    -H "Authorization: Bearer $(cat $OPENAI_API_FILE)" \
                    -H "Content-Type: application/json" \
                    -d "$data" 2>> "$debug_output")

    qa_debug "Full response: $response" 

    local answer=$(echo "$response" | jq -r '.choices[0].message.content')
    qa_debug "Extracted answer: $answer"

    if [[ -z "$answer" || "$answer" == "null" ]]; then
        qa_debug "No valid answer received or response is null."
        return 1
    fi

    if [[ ! -f "$QA_DIR/context.json" ]]; then
        echo "{\"context\": \"$context\"}" > "$QA_DIR/context.json"
    fi

    echo "$answer" > "$QA_DIR/last_answer"
    echo "$query_delta" >> "$QA_DIR/query_log"
    echo "$answer" >> "$QA_DIR/answer_log"

    local json_entry
    json_entry=$(jq -nc --arg query_delta "$query_delta" \
                        --arg answer "$answer" \
                '{query_delta: $query_delta, answer: $answer}')

    echo "$json_entry" >> "$QA_DIR/answers.json"

    # Append final answer to debug file and then output it
    qa_debug "Answer: $answer"
    echo "Answer: $answer" 
}


# Initialize system
qa_init() {
    if [ -f "$OPENAI_API_FILE" ]; then
        OPENAI_API=$(cat "$OPENAI_API_FILE")
    fi
    if [ -f "$QA_ENGINE_FILE" ]; then
        QA_ENGINE=$(cat "$QA_ENGINE_FILE")
    fi
    if [ -f "$QA_CONTEXT_FILE" ]; then
        QA_CONTEXT=$(cat "$QA_CONTEXT_FILE")
    fi
    qa_set_context "$QA_CONTEXT"  # Log initial context
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
    DEBUG_LOG=$QA_DIR/qa.log
    # Append new message with timestamp to the log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$DEBUG_LOG"

    # Trim the log file to keep only the last MAX_LOG_LINES lines
    # This creates a temporary file to hold the trimmed content
    tail -n $MAX_LOG_LINES "$DEBUG_LOG" > "$DEBUG_LOG.tmp"
    mv "$DEBUG_LOG.tmp" "$DEBUG_LOG"
}

qa_debug(){
   true && qa_log "[debug] $@"
}

qa_log_show(){
   cat $QA_DIR/qa.log
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
