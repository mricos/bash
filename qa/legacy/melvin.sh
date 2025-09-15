#!/usr/bin/env bash

# Respect caller overrides; fall back only if unset.
: "${QA_DIR:=$HOME/.qa}"

# Resolve sibling paths and source.
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# Load core and grep logger (qa_grep).
source "$SCRIPT_DIR/qa.sh"
source "$SCRIPT_DIR/grep.sh"

# Engine shortcuts. These only set QA_ENGINE for the call.
q1() { QA_ENGINE=gpt-3.5-turbo      qa_query "$@"; }
q2() { QA_ENGINE=gpt-4-turbo        qa_query "$@"; }
q3() { QA_ENGINE=gpt-4o-mini        qa_query "$@"; }
q4() { QA_ENGINE=chatgpt-4o-latest  qa_query "$@"; }


tag() {
  local lookback=0

  # Check if the first argument is a number (for lookback)
  if [[ $1 =~ ^[0-9]+$ ]]; then
    lookback=$1
    shift
  fi

  local db="$QA_DIR/db"

  # Get a sorted list of .answer files
  local files=($(ls "$db"/*.answer 2>/dev/null | sort -n))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No answer files found in $db" >&2
    return 1
  fi

  local last=$((${#files[@]} - 1))

  # Optional sanitization function; define _qa_sanitize_index if used
  local indexFromLast=$lookback
  if declare -f _qa_sanitize_index &>/dev/null; then
    indexFromLast=$(_qa_sanitize_index "$lookback")
  fi

  local index=$((last - indexFromLast))
  if (( index < 0 || index > last )); then
    echo "Invalid lookback value: $lookback" >&2
    return 1
  fi

  local file=${files[$index]}
  local id=$(basename "$file" .answer)

  # Write the rest of the arguments to the .tags file
  echo "${@}" >>  "$db/${id}.tags"
}

tags(){
    local files=($(ls $QA_DIR/db/*.tags | sort -n))
    printf "%s\n" ${files[@]}
}

fa_simple() {
    # Set default values for parameters, allowing overrides
    local width=${2:-$((COLUMNS - 8 ))}
    a "${@}" | glow --pager -s dark -w "$width"
}


fa_tagged() {
  local db="$QA_DIR/db"
  local args=("$@")
  local offset=0
  local search_tags=()
  local -a match_ids=()

  # Separate search tags and optional numeric offset
  for ((i=0; i < ${#args[@]}; i++)); do
    if [[ ${args[$i]} =~ ^[0-9]+$ ]]; then
      offset=${args[$i]}
      break
    else
      search_tags+=("${args[$i]}")
    fi
  done

  shopt -s nullglob
  for tag_file in "$db"/*.tags; do
    id=$(basename "$tag_file" .tags)
    answer_file="$db/$id.answer"
    prompt_file="$db/$id.prompt"
    
    [[ -f "$answer_file" && -f "$prompt_file" ]] || continue

    tag_content=$(tr '\n' ' ' < "$tag_file")
    match=1
    for tag in "${search_tags[@]}"; do
      if ! grep -iqw "$tag" <<< "$tag_content"; then
        match=0
        break
      fi
    done

    if [[ $match -eq 1 ]]; then
      match_ids+=("$id")
    fi
  done
  shopt -u nullglob

  # Save match list globally (qa_list)
  export qa_list=("${match_ids[@]}")
  local total=${#qa_list[@]}

  if (( total == 0 )); then
    echo "No matches for tags: ${search_tags[*]}" >&2
    return 1
  fi

  local idx=$(_qa_sanitize_index "$offset")
  local real_idx=$((total - 1 - idx))

  if (( real_idx < 0 || real_idx >= total )); then
    echo "Offset $offset is out of bounds. Found $total match(es)." >&2
    return 1
  fi

  local target_id="${qa_list[$real_idx]}"
  local prompt_file="$db/$target_id.prompt"
  local answer_file="$db/$target_id.answer"
  local tags_file="$db/$target_id.tags"

  echo "[qa_tagged/${real_idx}/$total - id $target_id]"
  echo "Prompt: $(head -n 1 "$prompt_file" | _truncate_middle)"
  echo -e "\n--- Answer ---\n"
  cat "$answer_file"
  echo -e "\nTags: $(tr '\n' ' ' < "$tags_file")"
}


qa_list_show() {
  local i=${#qa_list[@]}
  for id in "${qa_list[@]}"; do
    ((i--))
    local prompt=$(head -n 1 "$QA_DIR/db/$id.prompt")
    echo "$i: $id: $prompt" | _truncate_middle
  done
}



fa_grep() {
    local term=$1
    local offset=$2

    if [[ -z "$term" ]]; then
        echo "Usage: fa_grep <term> [offset]" >&2
        return 1
    fi

    local db="$QA_DIR/db"
    local scores=()
    local ids=()

    shopt -s nullglob
    for a_file in "$db"/*.answer; do
        local id=$(basename "$a_file" .answer)
        local p_file="$db/$id.prompt"
        local score=0

        grep -iq "$term" "$p_file" && ((score += 1))
        grep -iq "$term" "$a_file" && ((score += 2))

        if (( score > 0 )); then
            scores+=("$score:$id")
        fi
    done
    shopt -u nullglob

    if (( ${#scores[@]} == 0 )); then
        echo "No matches found for term: $term" >&2
        return 1
    fi

    # Sort by score descending, then ID for stable ordering
    IFS=$'\n' sorted=($(printf "%s\n" "${scores[@]}" | sort -t: -k1,1nr -k2,2))
    unset IFS

    local lastIndex=$((${#sorted[@]} - 1))
    local indexFromLast=$(_qa_sanitize_index "$offset")
    local index=$((lastIndex - indexFromLast))

    if (( index < 0 || index > lastIndex )); then
        echo "Index out of range. Found ${#sorted[@]} entries for term '$term'." >&2
        return 1
    fi

    local entry="${sorted[$index]}"
    local id="${entry#*:}"
    local prompt_file="$db/$id.prompt"
    local answer_file="$db/$id.answer"

    local info="[QA/$tag/$((index+1))/${lastIndex}$answer_file]"
    printf "[%s: %s]\n\n" "$id" "$(head -n 1 "$prompt_file" | _truncate_middle)"
    cat "$answer_file"
    printf "\n%s\n" "$info"
}

qa_db_nuke(){
    read -p "Delete all queries and responses? [y/N] " -n 1 -r
    local db="$QA_DIR/db"
    rm -rf "$db"
    mkdir -p "$db"
    echo ""
}


