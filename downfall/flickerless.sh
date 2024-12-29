#!/bin/bash

header="Random Binary Data Generator"
footer="Press Ctrl-C to exit"

while true; do
  # Get the terminal size
  rows=$(tput lines)
  cols=$(tput cols)
  
  # Calculate the buffer size
  buffer_size=$((rows - 4)) # Leave room for the prompt, header, footer, and last line
  header_size=1 # The header is one line
  
  # Generate random binary data and add it to the buffer
data=$(dd if=/dev/urandom bs=4 count=1 2>/dev/null \
  | hexdump -v -e '/1 "%02X "' \
  | awk '{print $1 $2 " " $3 $4 " " $5 $6 " " $7 $8}'
)

echo "$data"
  
  # Keep the buffer within the allowed size
  while [ "${#buffer[@]}" -gt "$buffer_size" ]; do
    buffer=("${buffer[@]:1}")
  done
  
  # Build the output string
  out=""
  
  # Add the header
  header_length=${#header}
  header_spaces=$(( (cols - header_length) / 2 ))
  out+="$(tput cup 0 $header_spaces)"
  out+="$header"
  
  # Add the buffer
  buffer_start=$((header_size)) # Include the first line of the buffer
  buffer_end=$((buffer_size + header_size)) # Account for the header and buffer size
  for (( i=$buffer_start; i<=$buffer_end; i++ )); do
    out+="$(tput cup $i 0)"
    out+="${buffer[$i - $header_size]:0:8} "
    out+="${buffer[$i - $header_size]:8:8} "
    out+="${buffer[$i - $header_size]:16:8} "
    out+="${buffer[$i - $header_size]:24:8}"
  done
  
  # Add the footer
  out+="$(tput cup $((rows - 2)) 0)" # Move the cursor to the second-to-last line and first column
  out+="$footer"
  
  # Clear the screen and echo the output
  tput clear
  echo -e "$out"
  
  # Wait for a second
  sleep 1
done
