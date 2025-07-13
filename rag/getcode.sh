getcode() {
    local index="${1:-1}"  # Default to first code block
    local count=0
    local collecting=false
    local block=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            if $collecting; then
                # End of block
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
                # Start of block
                collecting=true
                block=""
            fi
        elif $collecting; then
            block+="$line"$'\n'
        fi
    done

    if [[ "$index" != "all" && "$count" -lt "$index" ]]; then
        echo "Code block #$index not found." >&2
        return 1
    fi
}
