qa_margin() {
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

qa_colorize_js_code() {
  awk '
    BEGIN { 
      # Define ANSI color codes
      COLOR_CODE="\033[36m"; # Cyan for JavaScript code
      RESET_COLOR="\033[0m"; # Reset to default terminal color
    }
    
    /^```javascript/ { 
      # Start colorizing on finding the start of a JavaScript code block
      in_code_block=1; 
      print COLOR_CODE; 
      next; 
    }
    
    /^```/ && in_code_block { 
      # Stop colorizing on finding the end of a JavaScript code block
      in_code_block=0; 
      print RESET_COLOR; 
      next; 
    }
    
    in_code_block { 
      # Indent and print lines within a code block
      print "    " $0; 
      next; 
    }
    
    { 
      # Print non-code lines as they are
      print; 
    }
  '
}
