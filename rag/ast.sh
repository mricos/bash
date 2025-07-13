rag_bash_ast(){
  shfmt --to-json
}

rag_ast_bash(){
  shfmt --from-json -i 2
}

rag_ast_pathvars() {
  local -a stack=()
  local key val depth kvbuf=""
  local indent=""
  local inside=0

  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Match object start: "Key": {
    if [[ "$line" =~ ^\"([^\"]+)\"[[:space:]]*:[[:space:]]*\{$ ]]; then
      key="${BASH_REMATCH[1]}"
      stack+=("$key")
      kvbuf=""
      continue

    # Match simple key-value: "key": value,
    elif [[ "$line" =~ ^\"([^\"]+)\"[[:space:]]*:[[:space:]]*\"?([^\",]*)\"?[[:space:]]*,?$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      kvbuf+=" $k=$v"
      continue

    # Closing object: flush
    elif [[ "$line" == "}"* ]]; then
      if (( ${#stack[@]} > 0 )); then
        depth="${#stack[@]}"
        indent=$(printf "%*s" $((depth - 1)) "")
        last="${stack[-1]}"
        printf "%s%s=(%s )\n" "$indent" "$last" "$kvbuf"
        unset "stack[${#stack[@]}-1]"
        kvbuf=""
      fi
    fi
  done
}

rag_ast_patchfn() {
  local replace_only=0

  # Parse flags
  while [[ "$1" == -* ]]; do
    case "$1" in
      -r|--replace-only) replace_only=1 ;;
      --) shift; break ;;
      *) echo "Unknown flag: $1" >&2; return 1 ;;
    esac
    shift
  done

  local file="$1"
  [[ -z "$file" || ! -f "$file" ]] && { echo "Usage: $FUNCNAME [-r|--replace-only] <file>" >&2; return 1; }
  shift

  local tmpfn
  tmpfn=$(mktemp)
  cat > "$tmpfn"

  # Extract function name from pasted fn
  local fn_name
  fn_name=$(shfmt -tojson < "$tmpfn" | jq -r '
    .Stmts[]? | select(.Cmd.Type == "FuncDecl") | .Cmd.Name.Value
  ')


  # Locate function range in target file
  eval "$(shfmt -tojson < "$file" | jq -r --arg name "$fn_name" '
    .. | objects | select(.Type? == "FuncDecl" and .Name.Value == $name)
    | "start=" + (.Pos.Line|tostring) + "; end=" + (.End.Line|tostring)
  ')"

  if [[ -z "$start" || -z "$end" ]]; then
    if (( replace_only )); then
      echo "Function '$fn_name' not found in $file (strict mode)." >&2
      rm -f "$tmpfn"
      return 1
    else
      # Append
      cat "$file"
      echo
      cat "$tmpfn"
      rm -f "$tmpfn"
      return 0
    fi
  fi

  # Replace function region
  {
    head -n $((start - 1)) "$file"
    cat "$tmpfn"
    tail -n +"$((end + 1))" "$file"
  }

  rm -f "$tmpfn"
}
 
