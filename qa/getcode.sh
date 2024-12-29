alias getcode=qa_getcode

qa_getcode() {
    # Ensure QA_DIR is set and valid
    if [ -z "$QA_DIR" ]; then
        echo "QA_DIR is not set. Please set it before running." >&2
        return 1
    fi

    # Create temporary directory if it doesn't exist
    local temp_dir="/tmp/qacode"
    [ ! -d "$temp_dir" ] && mkdir -p "$temp_dir"

    # Initialize variables
    local counter=1
    local inside_code_block=false
    local parent_id=$(qa_id "$QA_DIR/last_answer")
    local outfile=""

    # Read lines from stdin
    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            if $inside_code_block; then
                # Close current code block
                inside_code_block=false
                outfile=""
            else
                # Start a new code block
                inside_code_block=true
                outfile="$temp_dir/${parent_id}.${counter}.code"
                touch "$outfile"
                counter=$((counter + 1))
            fi
        elif $inside_code_block && [ -n "$outfile" ]; then
            # Write to the file if inside a code block
            echo "$line" >> "$outfile"
        fi
    done

    # Default to the first code block if no argument is provided
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
