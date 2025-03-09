#!/bin/bash
# multisplit.sh
# Splits a concatenated file into individual files based on markers.
# Expected format:
#   #MULTICAT_START#
#   # dir: /original/path/to/dir
#   # file: filename.txt
#   # notes:
#   #MULTICAT_END#
# Followed by the file's content.

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
# Parameters:
#   $1 - Block index (number)
#   $2 - file_dir
#   $3 - file_name
#   $4 - file_content
#   $5 - yolo flag (1: force overwrite; 0: prompt)
#   $6 - print_mode flag (1: print to stdout; 0: write to file)
output_block() {
    local index="$1"
    local file_dir="$2"
    local file_name="$3"
    local file_content="$4"
    local yolo="$5"
    local print_mode="$6"

    if [[ "$print_mode" -eq 1 ]]; then
        safe_printf "---------------------------------"
        safe_printf "file %d: %s" "$index" "$file_name"
        safe_printf "location: %s" "$file_dir"
        safe_printf "---------------------------------"
        safe_printf "%s" "$file_content"
        safe_printf "---------------------------------"
    else
        # Determine output directory
        local output_dir="$file_dir"
        local output_file="$output_dir/$file_name"
        local output_file_dir
        output_file_dir=$(dirname "$output_file")
        if [[ ! -d "$output_file_dir" ]]; then
            mkdir -p "$output_file_dir"
        fi
        if [[ -f "$output_file" && $yolo -eq 0 ]]; then
            while true; do
                printf "File exists: %s\nOverwrite? [y/n]: " "$output_file"
                read -r answer </dev/tty
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

# parse_multicat: Parses the concatenated file and processes each file block.
# Parameters:
#   $1 - Input file
#   $2 - yolo flag (1: force overwrite; 0: prompt)
#   $3 - print_mode flag (1: print to stdout; 0: write to file)
parse_multicat() {
    local input_file="$1"
    local yolo="$2"
    local print_mode="$3"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' not found." >&2
        return 1
    fi

    local file_dir=""
    local file_name=""
    local file_content=""

    # Skip any lines before the first file block.
    while IFS= read -r line; do
        if [[ "$line" == "#MULTICAT_START#" ]]; then
            break
        fi
    done < "$input_file"

    # State machine: state "none", "header", "content"
    local state="none"
    local block_index=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$state" == "none" ]]; then
            if [[ "$line" == "#MULTICAT_START#" ]]; then
                state="header"
                file_dir=""
                file_name=""
                file_content=""
            fi
        elif [[ "$state" == "header" ]]; then
            if [[ "$line" == "#MULTICAT_END#" ]]; then
                state="content"
            else
                if [[ "$line" == "# dir: "* ]]; then
                    file_dir="${line#"# dir: "}"
                elif [[ "$line" == "# file: "* ]]; then
                    file_name="${line#"# file: "}"
                fi
            fi
        elif [[ "$state" == "content" ]]; then
            if [[ "$line" == "#MULTICAT_START#" ]]; then
                block_index=$((block_index + 1))
                output_block "$block_index" "$file_dir" "$file_name" "$file_content" "$yolo" "$print_mode"
                state="header"
                file_dir=""
                file_name=""
                file_content=""
            else
                file_content+="$line"$'\n'
            fi
        fi
    done < "$input_file"

    if [[ "$state" == "content" ]]; then
        block_index=$((block_index + 1))
        output_block "$block_index" "$file_dir" "$file_name" "$file_content" "$yolo" "$print_mode"
    fi
}

# display_help: Shows the help message.
display_help() {
  cat <<EOF
multisplit: Split concatenated files into individual files based on markers.
Usage: $(basename "$0") [OPTIONS] INPUT_FILE
Options:
  -y, --yolo      Overwrite all files without prompting.
  -p, --print     Print extracted file blocks (header and content) to screen.
  -h, --help      Display this help message.
EOF
}

# Default flag values.
yolo=0
print_mode=0
input_file=""

# Parse command-line arguments.
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
            fi
            shift
            ;;
    esac
done

if [[ -z "$input_file" ]]; then
    echo "Error: Input file is required." >&2
    display_help
    exit 1
fi

parse_multicat "$input_file" "$yolo" "$print_mode"
