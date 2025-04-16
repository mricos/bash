#!/usr/bin/env bash
# multisplit.sh
# Extract MULTICAT blocks into files using optional output path and root trimming.

set -euo pipefail

# safe_printf: Ensures the format string is handled safely.
safe_printf() {
  local fmt="$1"
  shift
  if [[ "$fmt" == -* ]]; then
    fmt=" $fmt"
  fi
  printf "$fmt\n" "$@"
}

# output_block: Writes or displays a single file block.
output_block() {
  local index="$1"
  local file_dir="$2"
  local file_name="$3"
  local file_content="$4"
  local yolo="$5"
  local print_mode="$6"
  local prefix_dir="${7:-}"
  local cut_dir="${8:-}"

  if [[ "$print_mode" -eq 1 ]]; then
    safe_printf "---------------------------------"
    safe_printf "file %d: %s" "$index" "$file_name"
    safe_printf "location: %s" "$file_dir"
    safe_printf "---------------------------------"
    safe_printf "%s" "$file_content"
    safe_printf "---------------------------------"
  else
    local relative_path="$file_dir"
    if [[ -n "$prefix_dir" ]]; then
      if [[ -n "$cut_dir" && "$file_dir" == "$cut_dir"* ]]; then
        relative_path="${file_dir#$cut_dir}"
        relative_path="${relative_path#/}" # Remove leading slash
      fi
      output_dir="$prefix_dir/$relative_path"
    else
      output_dir="$file_dir"
    fi

    local output_file="$output_dir/$file_name"
    mkdir -p "$(dirname "$output_file")"

    if [[ -f "$output_file" && "$yolo" -eq 0 ]]; then
      while true; do
        printf "File exists: %s\nOverwrite? [y/n]: " "$output_file"
        read -r answer </dev/tty || true
        answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [[ "$answer" == "y" ]]; then
          break
        elif [[ "$answer" == "n" || -z "$answer" ]]; then
          echo "Skipping '$output_file'."
          return
        else
          echo "Invalid input. Enter 'y' or 'n'."
        fi
      done
    fi
    printf "%s" "$file_content" > "$output_file"
    echo "Extracted '$output_file'."
  fi
}

# parse_multicat: Parses MULTICAT blocks.
parse_multicat() {
  local input_spec="$1"
  local yolo="$2"
  local print_mode="$3"
  local prefix_dir="${4:-}"
  local cut_dir="${5:-}"

  local file_dir="" file_name="" file_content="" state="none" block_index=0

  local input_stream

  # Support input from file or stdin (-)
  if [[ "$input_spec" == "-" ]]; then
    input_stream="$(cat)"
  elif [[ -t 0 && ! -f "$input_spec" ]]; then
    echo "Error: Input file '$input_spec' not found." >&2
    exit 1
  else
    input_stream="$(cat "$input_spec")"
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$state" in
      "none")
        [[ "$line" == "#MULTICAT_START#" ]] && state="header"
        ;;
      "header")
        if [[ "$line" == "#MULTICAT_END#" ]]; then
          state="content"
        else
          [[ "$line" == "# dir: "* ]] && file_dir="${line#"# dir: "}"
          [[ "$line" == "# file: "* ]] && file_name="${line#"# file: "}"
        fi
        ;;
      "content")
        if [[ "$line" == "#MULTICAT_START#" ]]; then
          block_index=$((block_index + 1))
          output_block "$block_index" "$file_dir" "$file_name" "$file_content" "$yolo" "$print_mode" "$prefix_dir" "$cut_dir"
          file_dir="" file_name="" file_content=""
          state="header"
        else
          file_content+="$line"$'\n'
        fi
        ;;
    esac
  done <<< "$input_stream"

  if [[ "$state" == "content" ]]; then
    block_index=$((block_index + 1))
    output_block "$block_index" "$file_dir" "$file_name" "$file_content" "$yolo" "$print_mode" "$prefix_dir" "$cut_dir"
  fi
}

# display_help: Show usage information.
display_help() {
  cat <<EOF
multisplit: Extract MULTICAT-defined files.

Usage:
  $(basename "$0") [OPTIONS] INPUT_FILE [PREFIX_DIR] [CUTOFF_DIR]

Options:
  -y, --yolo     Overwrite files without prompting
  -p, --print    Print to stdout instead of writing files
  -h, --help     Show this help message

Examples:
  ./multisplit.sh input.txt
  ./multisplit.sh input.txt ./out
  ./multisplit.sh input.txt ./out /Users/foo/src
  cat input.txt | ./multisplit.sh -p -         # read from stdin and print
EOF
}

# Main argument parsing
yolo=0
print_mode=0
input_file=""
prefix_dir=""
cut_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yolo)
      yolo=1
      shift
      ;;
    -p|--print)
      print_mode=1
      shift
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    *)
      if [[ -z "$input_file" ]]; then
        input_file="$1"
      elif [[ -z "$prefix_dir" ]]; then
        prefix_dir="$1"
      elif [[ -z "$cut_dir" ]]; then
        cut_dir="$1"
      fi
      shift
      ;;
  esac
done

# If input_file is not set and we’re not in a terminal, assume stdin
if [[ -z "$input_file" && ! -t 0 ]]; then
  input_file="-"
fi

if [[ -z "$input_file" ]]; then
  echo "Error: Input file is required." >&2
  display_help
  exit 1
fi

parse_multicat "$input_file" "$yolo" "$print_mode" "$prefix_dir" "$cut_dir"
