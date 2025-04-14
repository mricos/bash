QA_SRC="$HOME/src/bash/qa/qa.sh"
QA_DIR="$HOME/.qa"

qq() { qa_query "$@"; }
q1() { QA_ENGINE=gpt-3.5-turbo; qa_query "$@"; }
q2() { QA_ENGINE=gpt-4-turbo; qa_query "$@"; }
q3() { QA_ENGINE=gpt-4o-mini; qa_query "$@"; }
q4() { QA_ENGINE=chatgpt-4o-latest; qa_query "$@"; }
qaq() { qa_queue; }

QA_ENGINE_FILE="$QA_DIR/engine"
QA_CONTEXT_FILE="$QA_DIR/context"
OPENAI_API_FILE="$QA_DIR/api_key"

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source $SCRIPT_DIR/getcode.sh

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

_truncate_middle() {
  local input

  if [[ -n "$1" ]]; then
    input="$1"
  else
    input="$(cat)"
  fi

  # Set default COLUMNS if not set
  local cols=${COLUMNS:-80}
  local maxwidth=$((cols - 2))
  local len=${#input}

  if (( len <= maxwidth )); then
    echo "$input"
  else
    local keep=$(( (maxwidth - 3) / 2 ))
    local start="${input:0:keep}"
    local end="${input: -keep}"
    echo "${start}...${end}"
  fi
}
qa_test(){
  qq what is the fastest land animal?
  a
}

qa_query(){
  q_gpt_query ${@}
  QA_QUEUE+=($(a_last_id))
}

q_gpt_query ()
{
    echo "Using $QA_ENGINE" >&2
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
    data=$(jq -nc --arg model "$QA_ENGINE" \
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
        echo "Curl command failed. Check the API endpoint connection."
        return 1
    fi

    echo "$response" > "$db/$id.response"
    local answer=$(echo "$response" | jq -r '.choices[0].message.content')

    if [[ -z "$answer" || "$answer" == "null" ]]; then
        "No valid answer received or response is null."  > "$db/$id.answer"
        return 1
    fi

    echo "$answer" > "$db/$id.answer"
    [ ! -z "$1" ] && echo "$answer"       # show for single line questions
    
} 

qa_queue(){
  local i=${#QA_QUEUE[@]}
  for id in ${QA_QUEUE[@]}; do
     ((i--))
     echo "$i:$id: $(head -n 1 $QA_DIR/db/$id.prompt)" \
     | _truncate_middle
  done
}
# Show documentation
qa_help() {
    cat <<EOF
   Q&A Command Line Tool Documentation:
   ------------------------------------
   qa_help          - Show this documentation.
   qa_status        - Display current system status.
   qa_select_engine - Select the engine from available OpenAI engines.
   qa_set_engine    - Set the Q&A engine (default: OpenAI).
   qa_set_apikey    - Set the API key for the Q&A engine.
   qa_set_context   - Set default context for queries.
   a                - Most recent answer
   fa 1             - Formatted 2nd most recent
   q                - Query with detailed output

EOF
}

# Display current system status
qa_status() {
    echo
    echo "  Query and Answer system, ver 007m2"
    echo
    echo "API Key file: $OPENAI_API_FILE"
    echo "API Key: $(cat $OPENAI_API_FILE)"
    echo "Engine: $(cat $QA_ENGINE_FILE)"
    echo "Context: $(cat $QA_CONTEXT_FILE)"
}

# Set the API key for the Q&A engine
qa_set_apikey() {
    echo "$1" > "$OPENAI_API_FILE"
}

# Set the Q&A engine (default: OpenAI)
qa_set_engine() {
    QA_ENGINE="$1"
    echo "$QA_ENGINE" > "$QA_ENGINE_FILE"
}

# Set default context for queries
qa_set_context() {
    echo "$1" > "$QA_CONTEXT_FILE"
}

# List and select an engine from OpenAI's available engines
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

# Initialize system
qa_init() {

    # Ensure the db directory exists
    mkdir -p "$QA_DIR/db"       # all queries and responses

    if [ -f "$OPENAI_API_FILE" ]; then
       OPENAI_API=$(cat "$OPENAI_API_FILE")
    fi
    if [ -f "$QA_ENGINE_FILE" ]; then
        QA_ENGINE=$(cat "$QA_ENGINE_FILE")
    fi
    if [ -f "$QA_CONTEXT_FILE" ]; then
        QA_CONTEXT=$(cat "$QA_CONTEXT_FILE")
    fi
    if [ -z "$QA_QUEUE" ]; then
        QA_QUEUE=()               # per-shell chain of answers
    fi


    qa_set_context "$QA_CONTEXT"  # Set initial context
}


q() {
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

a_last_id(){
    basename $(a_last_answer_file) .answer    
}

a_last_answer_file(){
    local files=($(ls $QA_DIR/db/*.answer | sort -n))
    lastIndex=$((${#files[@]}-1))  # zero index
    #echo "$db/*.answer: ${#files[@]}, lastIndex=$lastIndex" >&2
    echo ${files[$lastIndex]}
}
a_last_answer(){
    cat $(a_last_answer_file)
}

a() {
    local id file files info index lastIndex
    local N=${#QA_QUEUE[@]}
    local db=$QA_DIR/db
    local indexFromLast=$(_qa_sanitize_index $1)
    if (( indexFromLast < N )); then
        index=$(($N-$indexFromLast -1 ))
        id=${QA_QUEUE[$index]}
        file=$db/$id.answer
        info="[QA/local/$((index+1))/${N}${file} ]"
    else 
        files=($(ls $db/*.answer | sort -n))
        lastIndex=$((${#files[@]}-1))
        index=$(($lastIndex-$indexFromLast))
        file="${files[$index]}"
        id=$(basename $file .answer)
        info="[QA/global/$((index+1))/${lastIndex}${file} ]"
    fi 
    
    echo "[$id: $(head -n 1 $db/$id.prompt | _truncate_middle )]"
    echo 
    cat $file
    echo
    echo $info
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
    read -p "Delete all queries and responses? [y/N] " -n 1 -r
    local db="$QA_DIR/db"
    rm -rf "$db"
    mkdir -p "$db"
    echo ""
}


fa() {
    # Set default values for parameters, allowing overrides
    local width=${2:-$((COLUMNS - 8 ))}
    a ${@} | glow --pager -s dark -w "$width"
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

source $SCRIPT_DIR/export.sh
qa_init

