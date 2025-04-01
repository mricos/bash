#!/usr/bin/env bash
# multicat.sh
# Concatenates multiple files (or files within directories) into a single
# multicat stream, embedding file metadata in header blocks.

set -euo pipefail

# Source the help documentation
source "$(dirname "$0")/help.sh"

# Global arrays for file inclusion and exclusion, and recursion flag.
include_files=()
exclude_files=()
recursive=0

# array_to_regex
# Converts array elements into a regex pattern suitable for =~ operator.
array_to_regex() {
  local IFS="|"
  if [[ $# -eq 0 ]]; then
    echo '^$'
  else
    echo ".*($*)$"
  fi
}

# recurse_dirs
# Recursively lists files from a directory, respecting exclusions.
# Outputs absolute paths of files found.
recurse_dirs() {
  local dir="$1"
  local exclude_regex
  exclude_regex=$(array_to_regex "${exclude_files[@]:-}")

  find -L "$dir" -type f -print0 | while IFS= read -r -d $'\0' file; do
    local file_with_path
    file_with_path=$(realpath "$file")

    if [[ ${#exclude_files[@]} -gt 0 && "$file_with_path" =~ $exclude_regex ]]; then
      continue
    fi

    echo "$file_with_path"
  done
}

# load_include_files_from_file
# Loads include file paths from an external file.
load_include_files_from_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
        include_files+=("$line")
      fi
    done < "$file_path"
  else
    echo "Error: Include file '$file_path' not found." >&2
    exit 1
  fi
}

# load_exclude_patterns_from_file
# Loads exclusion patterns from a file (like .gitignore or .multignore).
load_exclude_patterns_from_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
        exclude_files+=("$line")
      fi
    done < "$file_path"
  fi
}

# load_gitignore_files
# Loads .gitignore and .multignore patterns from the current directory downwards.
load_gitignore_files() {
  find . -name ".gitignore" -o -name ".multignore" -type f -print0 | \
    while IFS= read -r -d $'\0' file; do
      load_exclude_patterns_from_file "$file"
    done
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      shift
      if [[ $# -eq 0 || "$1" == -* ]]; then
        echo "Error: Missing argument for -i" >&2; exit 1;
      fi
      while [[ $# -gt 0 && "$1" != -* ]]; do
        include_files+=("$1")
        shift
      done
      ;;
    -f)
      shift
      if [[ $# -gt 0 && "$1" != -* ]]; then
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
    -*)
      echo "Error: Unknown option '$1'" >&2
      display_help
      exit 1
      ;;
    *)
      include_files+=("$1")
      shift
      ;;
  esac
done

# --- Pre-processing ---
if [[ ${#include_files[@]} -eq 0 ]]; then
  if [[ -f "./multmore.log" ]]; then
    echo "No input specified, defaulting to ./multmore.log" >&2
    include_files+=("./multmore.log")
  else
    echo "Error: No input files or directories specified." >&2
    display_help
    exit 1
  fi
fi

load_gitignore_files
exclude_regex=$(array_to_regex "${exclude_files[@]:-}")

# --- File Gathering ---
files_to_process=()
file_index=""
file_count=1

echo "Gathering files..." >&2

for item in "${include_files[@]}"; do
  if [[ ! -e "$item" ]]; then
    echo "Warning: Input item '$item' not found. Skipping." >&2
    continue
  fi

  item_path=$(realpath "$item")

  if [[ -f "$item" && ${#exclude_files[@]} -gt 0 && "$item_path" =~ $exclude_regex ]]; then
    echo "Skipping excluded file: $item_path" >&2
    continue
  fi

  if [[ -f "$item" ]]; then
    files_to_process+=
::contentReference[oaicite:0]{index=0}
 

