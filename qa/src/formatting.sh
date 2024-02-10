
qa_margin() {
    top=$1
    right=$2
    bottom=$3
    left=$4

    # Step 1: Pre-process the input to mark code blocks
    awk '
    BEGIN { in_code_block = 0; }
    /^```/ {
        in_code_block = !in_code_block;
        print; # Print the code block delimiter
        next;
    }
    { 
        if (in_code_block) {
            # Mark lines within code blocks
            print "CODE_BLOCK_START " $0 " CODE_BLOCK_END";
        } else {
            print;
        }
    }' | \
    # Step 2: Apply 'fmt' and margin adjustments outside code blocks
    while IFS= read -r line; do
        if [[ $line == "CODE_BLOCK_START "* && $line == *" CODE_BLOCK_END" ]]; then
            # Remove markers and print the original line (code block line)
            echo "${line//CODE_BLOCK_START /}"
            echo "${line// CODE_BLOCK_END/}"
        else
            # Apply left margin and fmt to non-code lines
            printf '%*s' $left | tr ' ' ' '
            echo "$line" | fmt -w $((COLUMNS-left-right))
        fi
    done

    # Step 3: Add bottom margin
    for (( i=0; i<bottom; i++ )); do
        echo
    done
}


qa_margin_old() {
  top=$1
  right=$2
  bottom=$3
  left=$4
 
  # Calculate the number of blank lines based on the top argument
  for (( i=0; i<top; i++ )); do
    echo
  done

  # Calculate the desired width for text formatting
  # This calculation considers both left and right margins
  let text_width=$COLUMNS-$left-$right

  # Check if calculated text width is positive
  if [ $text_width -le 0 ]; then
    echo "Error: Left and right margins exceed the available column width."
    return 1
  fi

  # Use sed to add left margin by padding spaces to the beginning of each line
  # Then use fmt to wrap text according to the calculated width
  sed "s/^/$(printf '%*s' $left)/" | fmt -w $text_width

  # Calculate the number of blank lines based on the bottom argument
  for (( j=0; j<bottom; j++ )); do
    echo
  done
}

qa_clear_screen() {
  for i in $(seq 1 $LINES); do
    echo
  done
}

qa_colorize_code() {
  awk '
    BEGIN {
      # Define ANSI color codes
      #COLOR_CODE="\033[36m";  # Cyan for code blocks
      COLOR_CODE="\033[36m";  # Correct way to start cyan
      #RESET_COLOR="\033[0m";  # Reset to default terminal color
      RESET_COLOR="\033[0m";  # Reset colors
      in_code_block=0;        # Initialize in_code_block as false
    }

    /^```/ {
      if (in_code_block) {
        # Exiting a code block
        print RESET_COLOR;
        in_code_block=0;  # Set in_code_block to false
      } else {
        # Entering a code block
        in_code_block=1;  # Set in_code_block to true
        print COLOR_CODE;
      }
      next;
    }

    in_code_block {
      # Print lines within a code block with indentation
      print "    " $0;
    }

    !in_code_block {
      # Print non-code lines as they are
      print;
    }
  '
}


fa(){
  qa_clear_screen
  a $1 | qa_colorize_code | qa_margin_old 4 4 4 4 | less -r
}
