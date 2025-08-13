#!/usr/bin/env bash
# multicat.sh — Concatenates files into MULTICAT format
set -euo pipefail

# --- Global ---
include_files=()
exclude_patterns=()
recursive=0
dryrun=0

# --- Helpers ---
usage() {
  echo "Usage: $0 [-r] [-x exclude.txt] [file|dir ...]"
  echo "  -r               Recurse into directories"
  echo "  -x <file>        Exclude patterns file"
  echo "  --dryrun         Show files that would be included"
  exit 1
}

array_to_regex() {
  local IFS="|"
  [[ $# -eq 0 ]] && echo '^$' || echo ".*($*)$"
}

load_excludes() {
  local path="$1"
  [[ -f "$path" ]] || return
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    exclude_patterns+=("$line")
  done < "$path"
}

resolve_files() {
  local item="$1"
  local resolved
  if ! resolved=$(realpath "$item" 2>/dev/null); then
    echo "Warning: cannot resolve $item" >&2; return
  fi

  if [[ -f "$resolved" ]]; then
    [[ "$resolved" =~ $exclude_regex ]] || echo "$resolved"
  elif [[ -d "$resolved" && $recursive -eq 1 ]]; then
    find "$resolved" -type f -print0 | while IFS= read -r -d '' f; do
      [[ "$f" =~ $exclude_regex ]] || realpath "$f"
    done
  elif [[ -d "$resolved" ]]; then
    echo "Skipping dir $resolved (use -r to recurse)" >&2
  fi
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r) recursive=1 ;;
    -x) shift; load_excludes "$1" ;;
    --dryrun) dryrun=1 ;;
    -h|--help) usage ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *) include_files+=("$1") ;;
  esac
  shift
done

[[ ${#include_files[@]} -eq 0 ]] && usage

exclude_regex=$(array_to_regex "${exclude_patterns[@]}")

all_files=()
for item in "${include_files[@]}"; do
  while IFS= read -r f; do
    all_files+=("$f")
  done < <(resolve_files "$item")
done

if [[ $dryrun -eq 1 ]]; then
  printf "%s\n" "${all_files[@]}"
  exit 0
fi

# --- Output MULTICAT Format ---
for f in "${all_files[@]}"; do
  dir=$(dirname "$f")
  base=$(basename "$f")
  {
    echo "#MULTICAT_START"
    echo "# dir: $dir"
    echo "# file: $base"
    echo "# notes:"
    echo "#MULTICAT_END"
    cat "$f"
    echo
  }
done
