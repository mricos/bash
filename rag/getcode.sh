getcode() {
  local index="${1:-1}"     # Default index is 1
  local count=0
  local collecting=false
  local block=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      if $collecting; then
        # End of a code block
        count=$((count + 1))
        if [[ "$index" == "all" ]]; then
          printf '%s\n' "$block"
        elif [[ "$count" -eq "$index" ]]; then
          printf '%s\n' "$block"
          return 0
        fi
        block=""
        collecting=false
      else
        # Start of a code block
        collecting=true
        block=""
      fi
    elif $collecting; then
      block+="$line"$'\n'
    fi
  done

  # If specific index not found
  if [[ "$index" != "all" ]]; then
    echo "Code block #$index not found." >&2
    return 1
  fi
}
