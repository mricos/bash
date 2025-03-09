#!/bin/bash
# multicat.sh
# Concatenate multiple files (or directories) into a single multicat stream,
# embedding file metadata in header blocks.
set -euo pipefail

# Global arrays for file inclusion and exclusion, and recursion flag.
include_files=()
exclude_files=()
recursive=0

# Convert array elements into a regex pattern.
array_to_regex() {
  local IFS="|"
  echo ".*($*)$"
}

# Recursively list files from a directory.
recurse_dirs() {
  local dir="$1"
  local exclude_regex
  exclude_regex=$(array_to_regex "${exclude_files[@]:-}")
  for file in "$dir"*; do
    if [[ -d "$file" ]]; then
      recurse_dirs "$file/"
    elif [[ -f "$file" ]]; then
      local file_with_path
      file_with_path=$(realpath "$file")
      # Skip file if it matches an exclusion pattern.
      if [[ ${#exclude_files[@]:-0} -gt 0 && "$file_with_path" =~ $exclude_regex ]]; then
        continue
      fi
      # If include_files is nonempty, include only matching files.
      if [[ ${#include_files[@]:-0} -gt 0 ]]; then
        local found=0
        for inc in "${include_files[@]}"; do
          if [[ "$file_with_path" == "$inc" ]]; then
            found=1
            break
          fi
        done
        [[ $found -eq 0 ]] && continue
      fi
      echo "$file_with_path"
    fi
  done
}

# Load include file paths from an external file.
load_include_files_from_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    while IFS= read -r line; do
      include_files+=("$line")
    done < "$file_path"
  else
    echo "Error: Include file '$file_path' not found." >&2
    exit 1
  fi
}

# Load exclusion patterns from a file.
load_exclude_patterns_from_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    while IFS= read -r line; do
      line=$(echo "$line" | tr -d '[:space:]')
      if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
        exclude_files+=("$line")
      fi
    done < "$file_path"
  fi
}

# Load .gitignore and .multignore patterns.
load_gitignore_files() {
  find . -name ".gitignore" -o -name ".multignore" -type f -print0 | \
    while IFS= read -r -d $'\0' file; do
      load_exclude_patterns_from_file "$file"
    done
}

display_help() {
  cat <<EOF
multicat: Concatenate files into a multicat stream with metadata headers.
Usage: $(basename "$0") [OPTIONS] [FILES...]
Options:
  -i FILE [FILE ...]   Directly include one or more files or directories.
  -f FILE              Load list of include files from the specified file.
  -r                   Recursively process directories.
  -h, --help          Display this help message.

Description:
  The multicat output consists of a header block for each file, formatted as:
    #MULTICAT_START#
    # dir: /original/path/to/dir
    # file: filename.txt
    # notes:
    #MULTICAT_END#
  followed by the file's contents. This format facilitates later extraction with multisplit.
EOF
}

# Parse command-line arguments.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        include_files+=("$1")
        shift
      done
      ;;
    -f)
      shift
      if [[ $# -gt 0 ]]; then
        load_include_files_from_file "$1"
        shift
      else
        echo "Error: Missing argument for -f" >&2
        exit 1
      fi
      ;;
    -r)
      recursive=1
      shift
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    *)
      include_files+=("$1")
      shift
      ;;
  esac
done

# If no files specified, default to multmore.log (if it exists).
if [[ ${#include_files[@]:-0} -eq 0 && ${#exclude_files[@]:-0} -eq 0 ]]; then
  if [[ -f "./multmore.log" ]]; then
    include_files+=("./multmore.log")
  fi
fi

load_gitignore_files

# Create temporary file to hold output.
tmp_file=$(mktemp)

# Build file index.
file_index=""
file_count=1

for file in "${include_files[@]:-}"; do
  if [[ -f "$file" ]]; then
    file_path=$(realpath "$file")
    if [[ ${#exclude_files[@]:-0} -gt 0 && "$file_path" =~ $(array_to_regex "${exclude_files[@]:-}") ]]; then
      continue
    fi
    file_index+="[$file_count] $file_path\n"
    file_count=$((file_count + 1))
  elif [[ -d "$file" && $recursive -eq 1 ]]; then
    recurse_dirs "$file/"
  elif [[ -d "$file" && $recursive -eq 0 ]]; then
    echo "Warning: '$file' is a directory. Use -r to process directories recursively." >&2
  fi
done

# Build file contents with header for each file.
file_contents=""
for file in "${include_files[@]:-}"; do
  if [[ -f "$file" ]]; then
    file_path=$(realpath "$file")
    if [[ ${#exclude_files[@]:-0} -gt 0 && "$file_path" =~ $(array_to_regex "${exclude_files[@]:-}") ]]; then
      continue
    fi
    file_content_tmp=$(cat "$file_path")
    file_dir=$(dirname "$file_path")
    file_name=$(basename "$file_path")
    file_contents+="#MULTICAT_START#\n"
    file_contents+="# dir: ${file_dir}\n"
    file_contents+="# file: ${file_name}\n"
    file_contents+="# notes:\n"
    file_contents+="#MULTICAT_END#\n"
    file_contents+="${file_content_tmp}\n\n"
  fi
done

{
  echo -e "$file_index"
  echo -e "$file_contents"
} > "$tmp_file"
cat "$tmp_file"
rm "$tmp_file"
