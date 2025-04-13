getcode() {
  local index=${1:-1}      # Default to code block #1
  local count=0
  local collecting=false
  local block=""
  
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      if $collecting; then
        count=$((count + 1))
        # Check if this is the code block to print
        if [ "$count" -eq "$index" ]; then
          printf '%s\n' "$block"
          return 0
        fi
        block=""
        collecting=false
      else
        collecting=true
        block=""  # Start collecting a new block
      fi
    elif $collecting; then
      block+="$line"$'\n'
    fi
  done

  echo "Code block #$index not found." >&2
  return 1
}
