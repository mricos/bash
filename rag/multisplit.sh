#!/usr/bin/env bash
# multisplit.sh: Extract MULTICAT blocks from a file or stdin.

set -euo pipefail

CUTOFF_DIR="$(pwd)"
OUTPUT_ROOT="./"

safe_printf() {
  local fmt="$1"; shift
  [[ "$fmt" == -* ]] && fmt=" $fmt"
  printf "$fmt\n" "$@"
}

write_block() {
  local idx="$1" dir="$2" name="$3" body="$4" yolo="$5" print="$6"
  local rel="${dir#$CUTOFF_DIR}"
  rel="${rel#/}"
  local path="$OUTPUT_ROOT/$rel/$name"

  if [[ "$print" -eq 1 ]]; then
    safe_printf "------------------------------"
    safe_printf "file %d: %s" "$idx" "$name"
    safe_printf "location: %s" "$dir"
    safe_printf "------------------------------"
    safe_printf "%s" "$body"
    safe_printf "------------------------------"
    return
  fi

  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" && "$yolo" -eq 0 ]]; then
    printf "File exists: %s\nOverwrite? [y/N]: " "$path"
    read -r ans </dev/tty || true
    ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
    [[ "$ans" != "y" ]] && echo "Skipping $path" && return
  fi
  printf "%s" "$body" > "$path"
  echo "Wrote $path"
}

process_input() {
  local stream="$1" yolo="$2" print="$3"
  local idx=0 dir="" name="" content="" state="none"

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$state" in
      none)
        [[ "$line" == "#MULTICAT_START" ]] && state="header"
        ;;
      header)
        [[ "$line" == "#MULTICAT_END" ]] && state="content"
        [[ "$line" == "# dir: "* ]] && dir="${line#"# dir: "}"
        [[ "$line" == "# file: "* ]] && name="${line#"# file: "}"
        ;;
      content)
        if [[ "$line" == "#MULTICAT_START" ]]; then
          idx=$((idx+1))
          write_block "$idx" "$dir" "$name" "$content" "$yolo" "$print"
          dir="" name="" content=""
          state="header"
        else
          content+="$line"$'\n'
        fi
        ;;
    esac
  done <<< "$stream"

  [[ "$state" == "content" ]] && idx=$((idx+1)) && write_block "$idx" "$dir" "$name" "$content" "$yolo" "$print"
}

show_help() {
  cat <<EOF
multisplit: Extract MULTICAT-defined files.

Usage:
  $0 [OPTIONS] INPUT_FILE|-    (use '-' for stdin)

Options:
  -y, --yolo     Overwrite files without prompting
  -p, --print    Print to stdout instead of writing files
  -h, --help     Show this help message

Examples:
  $0 out.mc
  $0 -y out.mc
  $0 -p -
  pbpaste | $0 -p -
EOF
}

main() {
  local yolo=0 print=0 input=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yolo) yolo=1 ;;
      -p|--print) print=1 ;;
      -h|--help) show_help; exit 0 ;;
      -*)
        echo "Unknown option: $1" >&2; exit 1
        ;;
      *)
        input="$1"
        ;;
    esac
    shift
  done

  if [[ -z "$input" ]]; then
    echo "Error: INPUT_FILE or '-' required" >&2
    show_help
    exit 1
  fi

  if [[ "$input" == "-" ]]; then
    process_input "$(cat)" "$yolo" "$print"
  elif [[ -f "$input" ]]; then
    process_input "$(cat "$input")" "$yolo" "$print"
  else
    echo "Invalid file: $input" >&2
    exit 1
  fi
}

main "$@"

