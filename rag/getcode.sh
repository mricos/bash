# Refactored script to extract and manage code blocks
getcode() {
    # Ensure QA_DIR is set and valid
    if [ -z "$QA_DIR" ]; then
        echo "QA_DIR is not set. Please set it before running." >&2
        return 1
    fi

    local temp_dir="/tmp/qacode"
    mkdir -p "$temp_dir" || return 1  # Ensure creation of the temp directory; exit if fails

    local counter=1
    local inside_code_block=false
    local parent_id=$(qa_id "$QA_DIR/last_answer")
    
    # Ensure parent_id retrieval was successful
    if [ -z "$parent_id" ]; then
        echo "Failed to retrieve parent ID from $QA_DIR/last_answer" >&2
        return 1
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            if $inside_code_block; then
                # Close current code block
                inside_code_block=false
            else
                # Start a new code block
                inside_code_block=true
                local outfile="$temp_dir/${parent_id}.${counter}.code"
                touch "$outfile" || return 1
                counter=$((counter+1))
            fi
        elif $inside_code_block; then
            # Write to the file if inside a code block
            echo "$line" >> "$outfile"
        fi
    done

    # Argument handling for selecting which code block to extract
    local index=${1:-1}
    local source_file="$temp_dir/${parent_id}.${index}.code"

    if [ -f "$source_file" ]; then
        cp "$source_file" "$QA_DIR/code"
        cat "$source_file"
    else
        echo "Specified file does not exist: $source_file" >&2
        return 1
    fi
}

# It's a good practice to not run scripts if they are sourced from another script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    getcode "$@"
fi
