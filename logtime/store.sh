logtime-store() {
    local timestamp=$(date +%s)
    local file="$LT_DIR/store/$LT_START.store"
    local input

    if [ -t 0 ]; then  # Check if stdin is a terminal (i.e., no piping)
        # Single-line input
        input="$@"
        echo "$timestamp $input" >> "$file"
    else
        # Multiline input
        echo "$timestamp START_MULTILINE" >> "$file"
        while IFS= read -r line; do
            echo "$line" >> "$file"
        done
        echo "$timestamp END_MULTILINE" >> "$file"
    fi
}

logtime-store-deprecated(){
  echo "$(date +%s) $@" >> $LT_DIR/store/$LT_START.store
}

logtime-stores(){
  cat $LT_DIR/store/$LT_START.store
}

