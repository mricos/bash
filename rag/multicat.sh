#!/usr/bin/env bash
# multicat.sh - Concatenates files. Designed for direct execution.
# Includes check to prevent running main logic if sourced.
# Uses help.sh for display_help function.
# Generated: Tuesday, April 1, 2025 at 12:33:11 AM PDT, Yucca Valley, California, United States

# --- Sourcing Check ---
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Error: This script is designed to be executed directly, not sourced." >&2
  echo "Usage: $(basename "$0") [options] [files...]" >&2
  return 0
fi

# --- Strict Mode & Dependencies ---
set -euo pipefail

if ! source "$(dirname "$0")/help.sh" 2>/dev/null; then
  echo "Warning: Could not source help.sh. Defining placeholder display_help." >&2
  display_help() {
    echo "Usage information unavailable ('help.sh' not found)."
  }
fi

# --- Global Variables ---
include_files=()
exclude_files=()
recursive=0
dryrun=0
files_to_process=()
file_index=""
file_count=1
exclude_regex='^$'

# --- Functions ---
array_to_regex() {
  local IFS="|"
  if [[ $# -eq 0 ]]; then
    echo '^$'
  else
    echo ".*($*)$"
  fi
}

recurse_dirs() {
  local dir="$1"
  local current_exclude_regex
  current_exclude_regex=$(array_to_regex "${exclude_files[@]:-}")
  find -L "$dir" -type f -print0 | while IFS= read -r -d $'\0' file; do
    local file_with_path
    if ! file_with_path=$(realpath "$file" 2>/dev/null); then
      echo "Warning: Failed to resolve path for '$file'. Skipping." >&2
      continue
    fi
    if [[ ${#exclude_files[@]} -gt 0 && "$file_with_path" =~ $current_exclude_regex ]]; then
      continue
    fi
    echo "$file_with_path"
  done
}

load_include_files_from_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: Include file '$file_path' not found or not a regular file." >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
      include_files+=("$line")
    fi
  done < "$file_path"
}

load_exclude_patterns_from_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    return 0
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
      exclude_files+=("$line")
    fi
  done < "$file_path"
}

load_gitignore_files() {
  find . -name ".gitignore" -o -name ".multignore" -type f -print0 | while IFS= read -r -d $'\0' file; do
    load_exclude_patterns_from_file "$file"
  done
}

add_file_to_output_list() {
  local file_to_add="$1"
  local source_info="$2"
  if [[ ! -f "$file_to_add" || ! -r "$file_to_add" ]]; then
    echo "Warning: Item '$file_to_add' not a readable file. Skipping addition." >&2
    return 1
  fi
  files_to_process+=("$file_to_add")
  echo "Adding file ($source_info): $file_to_add" >&2
  file_index+="[$file_count] $file_to_add\n"
  file_count=$((file_count + 1))
  return 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      shift
      initial_count=${#include_files[@]}
      while [[ $# -gt 0 && "$1" != -* ]]; do
        include_files+=("$1")
        shift
      done
      if [[ ${#include_files[@]} -eq $initial_count && ( $# -eq 0 || "$1" == -* ) ]]; then
        echo "Error: Missing argument for -i option." >&2
        display_help "$0"
        exit 1
      fi
      ;;
    -f)
      shift
      if [[ $# -gt 0 && "$1" != -* ]]; then
        load_include_files_from_file "$1"
        shift
      else
        echo "Error: Missing argument for -f option." >&2
        display_help "$0"
        exit 1
      fi
      ;;
    -x)
      shift
      if [[ $# -gt 0 && "$1" != -* ]]; then
        load_exclude_patterns_from_file "$1"
        shift
      else
        echo "Error: Missing argument for -x option." >&2
        display_help "$0"
        exit 1
      fi
      ;;
    -r)
      recursive=1
      shift
      ;;
    --dryrun)
      dryrun=1
      shift
      ;;
    -h|--help)
      display_help "$0"
      exit 0
      ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      display_help "$0"
      exit 1
      ;;
    *)
      include_files+=("$1")
      shift
      ;;
  esac
done

# --- Pre-Processing ---
if [[ ${#include_files[@]} -eq 0 ]]; then
  if [[ -f "./multmore.log" ]]; then
    echo "No input specified, defaulting to ./multmore.log" >&2
    include_files+=("./multmore.log")
  else
    echo "Error: No input files or directories specified." >&2
    display_help "$0"
    exit 1
  fi
fi

load_gitignore_files
exclude_regex=$(array_to_regex "${exclude_files[@]:-}")

for item in "${include_files[@]}"; do
  if [[ ! -e "$item" ]]; then
    echo "Warning: Input item '$item' not found. Skipping." >&2
    continue
  fi
  if ! item_path=$(realpath "$item" 2>/dev/null); then
    echo "Warning: Failed to resolve path for '$item'. Skipping." >&2
    continue
  fi
  if [[ -f "$item_path" && ${#exclude_files[@]} -gt 0 && "$item_path" =~ $exclude_regex ]]; then
    echo "Skipping explicitly excluded file: $item_path" >&2
    continue
  fi
  if [[ -f "$item_path" ]]; then
    add_file_to_output_list "$item_path" "direct" || true
  elif [[ -d "$item_path" ]]; then
    if [[ $recursive -eq 1 ]]; then
      echo "Recursively processing directory: $item_path/" >&2
      found_files_in_dir=()
      mapfile -t found_files_in_dir < <(recurse_dirs "$item_path/")
      if [[ ${#found_files_in_dir[@]} -eq 0 ]]; then
        echo "No processable files found in directory: $item_path/" >&2
      else
        for found_file in "${found_files_in_dir[@]}"; do
          add_file_to_output_list "$found_file" "recursive" || true
        done
      fi
    else
      echo "Warning: '$item_path' (from '$item') is a directory. Use -r to recurse. Skipping directory." >&2
    fi
  else
    echo "Warning: '$item_path' (from '$item') is not a regular file or directory. Skipping." >&2
  fi
done

# --- Handle Dry Run ---
if [[ $dryrun -eq 1 ]]; then
  if [[ ${#files_to_process[@]} -eq 0 ]]; then
    echo "Dry Run: No files would be processed." >&2
  else
    echo "Dry Run: The following ${#files_to_process[@]} files would be added, in order:" >&2
    printf "%s\n" "${files_to_process[@]}"
  fi
  exit 0
fi

# --- Output Generation ---
if [[ ${#files_to_process[@]} -eq 0 ]]; then
  echo "No files found to process." >&2
  exit 0
fi

if ! command -v mktemp > /dev/null; then
  echo "Error: 'mktemp' command not found." >&2
  exit 1
fi

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT HUP INT QUIT TERM

echo -e "$file_index" > "$tmp_file"
echo "" >> "$tmp_file"

for file_path in "${files_to_process[@]}"; do
  if [[ -f "$file_path" && -r "$file_path" ]]; then
    file_dir=$(dirname "$file_path")
    file_name=$(basename "$file_path")
    {
      echo "#MULTICAT_START"
      echo "# dir: ${file_dir}"
      echo "# file: ${file_name}"
      echo "# notes:"
      echo "#MULTICAT_END"
    } >> "$tmp_file"
    if ! cat "$file_path" >> "$tmp_file"; then
      echo "Warning: Failed to read content from '$file_path'." >&2
    fi
    echo "" >> "$tmp_file"
  fi
done

cat "$tmp_file"
echo "Done." >&2
exit 0
