# --- Algorithm Loading ---
load_and_init_algorithm() {
  local index=$1

  if [[ -z "${ALGO_FILES[$index]}" ]]; then
    STATUS_MESSAGE="Error: Invalid algorithm index $index"
    echo "ERROR: Invalid algorithm index $index" >&2
    return 1
  fi

  CURRENT_ALGO_INDEX=$index
  ALGO_FILE="${ALGO_FILES[$CURRENT_ALGO_INDEX]}"
  local algo_path="$ALGO_DIR/$ALGO_FILE"

  STATUS_MESSAGE="Loading ${ALGO_FILE}..."
  printf "\033[H\033[JLoading ${ALGO_FILE}..."

  if [[ ! -f "$algo_path" ]]; then
    STATUS_MESSAGE="Error: Algorithm file not found: $algo_path"
    echo "$STATUS_MESSAGE" >&2
    RUNNING=0
    return 1
  fi

  # --- Reset Engine State ---
  grid=()
  collapsed=()
  PAGES=()
  AVAILABLE_FORMATS=()
  TILED_RENDER_DATA=()
  CURRENT_RENDER_FORMAT="ASCII"
  CURRENT_DOC_PAGE=0
  RUNNING=0
  display_lines=()
  text_lines=()

  # --- Source Algorithm ---
  log_event "Sourcing algorithm script: $algo_path"
  source "$algo_path" || {
    STATUS_MESSAGE="Error sourcing ${ALGO_FILE}"
    echo "$STATUS_MESSAGE" >&2
    return 1
  }

  # --- Init Grid ---
  if declare -F init_grid &>/dev/null; then
    init_grid
    log_event "Called init_grid() for ${ALGO_FILE}"
  else
    echo "WARN: init_grid not found in $ALGO_FILE" >&2
    for ((y=0; y<ROWS; y++)); do
      for ((x=0; x<COLS; x++)); do
        collapsed["$y,$x"]=0
        grid["$y,$x"]="?"
      done
    done
  fi

  # --- Available Formats ---
  AVAILABLE_FORMATS=()
  AVAILABLE_FORMATS[ASCII]=1

  if declare -F get_enhanced_char &>/dev/null; then
    AVAILABLE_FORMATS[ENHANCED]=1
    log_event "Enhanced format supported (get_enhanced_char found)"
  fi

  if declare -F get_tiled_data &>/dev/null; then
    log_event "Checking for tiled rendering support..."
    local tiled_data_str
    tiled_data_str=$(get_tiled_data)

    if [[ -n "$tiled_data_str" ]]; then
      TILED_RENDER_DATA=()
      while IFS= read -r line; do
        if [[ "$line" =~ ^declare\ -[Aia]\ ([a-zA-Z0-9_]+)='(.+)'$ ]]; then
          local var="${BASH_REMATCH[1]}"
          local val="${BASH_REMATCH[2]}"
          case "$var" in
            tile_width|tile_height|error_symbol)
              TILED_RENDER_DATA[$var]="${val//\'/}"
              ;;
            TILE_TOPS|TILE_BOTS)
              TILED_RENDER_DATA["${var}_str"]="declare -A $var=$val"
              ;;
          esac
        fi
      done <<< "$tiled_data_str"

      if [[ -n "${TILED_RENDER_DATA[tile_width]}" &&
            -n "${TILED_RENDER_DATA[TILE_TOPS_str]}" &&
            -n "${TILED_RENDER_DATA[TILE_BOTS_str]}" ]]; then
        AVAILABLE_FORMATS[TILED]=1
        log_event "Tiled format initialized for ${ALGO_FILE}"
      else
        echo "WARN: get_tiled_data missing required vars" >&2
        unset TILED_RENDER_DATA
        declare -gA TILED_RENDER_DATA
      fi
    else
      echo "WARN: Tiled data empty; disabling" >&2
      unset TILED_RENDER_DATA
      declare -gA TILED_RENDER_DATA
    fi
  fi

  # --- Documentation Pages ---
  if declare -F init_docs &>/dev/null; then
    init_docs
    log_event "Called init_docs() for ${ALGO_FILE}"
  fi

  STATUS_MESSAGE="Loaded ${ALGO_FILE}"
  log_event "Finished loading ${ALGO_FILE}. Formats: ${!AVAILABLE_FORMATS[*]}"
  return 0
}

# --- Terminal Setup ---
setup_terminal() {
  tput civis
  log_event "Terminal setup: cursor hidden."
}

# --- Main Loop ---
main() {
  log_event "Engine main loop started"
  setup_terminal
  setup_keybindings

  if ! load_and_init_algorithm "$CURRENT_ALGO_INDEX"; then
    echo "FATAL: Unable to load initial algorithm." >&2
    exit 1
  fi

  render

  while [[ $SHOULD_EXIT -eq 0 ]]; do
    local key=""
    local key_pressed_requires_render=0

    if [[ $RUNNING -eq 1 ]]; then
      if declare -F update_algorithm &>/dev/null; then
        update_algorithm
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
          RUNNING=0
          STATUS_MESSAGE="Algorithm stopped (code $exit_code)"
          log_event "$STATUS_MESSAGE"
          key_pressed_requires_render=1
        fi
      else
        STATUS_MESSAGE="Error: update_algorithm not found"
        echo "$STATUS_MESSAGE" >&2
        RUNNING=0
        key_pressed_requires_render=1
      fi
    fi

    read -s -N 1 -t 0.01 key

    if [[ -n "$key" ]]; then
      if [[ "$key" == $'\e' ]]; then
        local seq=""
        read -s -N 2 -t 0.001 seq
        key+="$seq"
      fi

      if [[ -v KEY_ACTIONS[$key] ]]; then
        local action="${KEY_ACTIONS[$key]}"
        log_event "Key '$key' → $action"

        if [[ "$key" == $'\e'* ]]; then
          if [[ $FULL_SCREEN -eq 1 ]]; then
            eval "$action"
            key_pressed_requires_render=1
          else
            log_event "Arrow key ignored (not in fullscreen)"
          fi
        else
          eval "$action"
          key_pressed_requires_render=1
        fi
      else
        log_event "Key '$key' not mapped"
      fi
    fi

    if [[ $RUNNING -eq 1 ||
          ($RUNNING -eq 0 && $key_pressed_requires_render -eq 1) ]]; then
      render
    fi

    [[ $RUNNING -eq 0 && -z "$key" ]] && sleep 0.02
  done

  log_event "Engine main loop finished."
}
