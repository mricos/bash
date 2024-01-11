logtime-store() {
    local timestamp=$(date +%s)
    local file="$LT_DIR/store/$LT_START.store"
    local input="$@"

    # Single line input
    echo "$timestamp $input" >> "$file"
}

logtime-store-multiline() {
    local start_time=$(date +%s)
    local file="$LT_DIR/store/$LT_START.store"

    # Mark the start of a multiline input
    echo "$start_time START_MULTILINE" >> "$file"

    # Read and log each line
    while IFS= read -r line; do
        echo "$start_time $line" >> "$file"
    done

    # Mark the end of the multiline input
    local end_time=$(date +%s)
    echo "$end_time END_MULTILINE" >> "$file"
}


logtime-store-deprecated(){
  echo "$(date +%s) $@" >> $LT_DIR/store/$LT_START.store
}

logtime-stores(){
  cat $LT_DIR/store/$LT_START.store
}

