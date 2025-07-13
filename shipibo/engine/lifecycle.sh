#!/usr/bin/env bash

# --- Engine Lifecycle Functions ---
# Handles initialization, main loop, cleanup, algorithm loading.

# --- Source Dependencies --- 
# Source logging FIRST and unconditionally
source "./engine/logging.sh"
source_rc=$?
if [[ $source_rc -ne 0 ]]; then
    echo "FATAL LIFECYCLE: Failed to source ./engine/logging.sh (exit code $source_rc)" >&2
    exit 1
fi
# Check immediately if function exists after sourcing
if ! declare -F log_error &>/dev/null; then
    echo "FATAL LIFECYCLE: log_error function NOT defined immediately after sourcing logging.sh!" >&2
    exit 1
else
    log_event "LIFECYCLE: logging.sh sourced successfully, log_error defined."
fi

log_event "LIFECYCLE: Attempting to source glyph.sh..."
# Source glyph definitions (which also sources logging, harmless redundancy)
source "./engine/glyph.sh"

# --- Timing & FPS Globals ---
declare -g LAST_FRAME_TIME=0
declare -g CURRENT_FPS="---" # Start with placeholder
declare -g FRAME_COUNT=0

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
  # Force a full redraw on the *next* render cycle after algo switch
  FORCE_FULL_REDRAW=1
  # Optionally, immediately clear and show loading message:
  printf "\033[H\033[JLoading ${ALGO_FILE}...\n(Clearing cache...)"

  if [[ ! -f "$algo_path" ]]; then
    STATUS_MESSAGE="Error: Algorithm file not found: $algo_path"
    echo "$STATUS_MESSAGE" >&2
    RUNNING=0
    return 1
  fi

  # --- Reset Engine State (Simplified) ---
  grid=() # Now likely semantic states
  # possibilities=() # Might be deprecated if algo manages possibilities differently
  collapsed=() # Still needed for WFC-like algos
  # Explicitly unset and re-declare PAGES for robust clearing
  unset PAGES
  declare -ga PAGES=()
  # AVAILABLE_FORMATS=() # Deprecated
  # TILED_RENDER_DATA=() # Deprecated
  # CURRENT_RENDER_FORMAT="ASCII" # Now set in config.sh
  CURRENT_DOC_PAGE=0
  RUNNING=0
  # Clear rendering cache arrays
  PREVIOUS_DISPLAY_LINES=()
  PREVIOUS_TEXT_LINES=()
  display_lines=()
  text_lines=() # For side panel

  # --- Source Algorithm ---
  log_event "LIFECYCLE: Sourcing algorithm script: $algo_path"
  local t_start=$(date +%s.%N)
  source "$algo_path" || {
    STATUS_MESSAGE="Error sourcing ${ALGO_FILE}"
    echo "$STATUS_MESSAGE" >&2
    return 1
  }
  local t_sourced=$(date +%s.%N)
  log_event "LIFECYCLE: Sourced ${ALGO_FILE}. Time: $(echo "$t_sourced - $t_start" | bc -l) sec."

  # --- Check for Required Algo Functions ---
  local required_funcs=("init_grid" "update_algorithm" "init_docs" "get_state")
  local missing_funcs=()
  for func_name in "${required_funcs[@]}"; do
      if ! declare -F "$func_name" &>/dev/null; then
          missing_funcs+=("$func_name")
      fi
  done
  if [[ ${#missing_funcs[@]} -gt 0 ]]; then
       STATUS_MESSAGE="Error: Algo $ALGO_FILE missing: ${missing_funcs[*]}"
       # Assume log_error exists now, if logging.sh sourced correctly
       log_error "$STATUS_MESSAGE"
       return 1
  fi

  # --- Init Algorithm (optional) ---
  # Algorithms can define an init_algorithm function for one-time setup (e.g., populating rules)
  if declare -F "init_algorithm" &>/dev/null; then
      log_event "LIFECYCLE: Calling init_algorithm() for ${ALGO_FILE}..."
      local t_init_algo_start=$(date +%s.%N)
      init_algorithm
      local t_init_algo_end=$(date +%s.%N)
      log_event "LIFECYCLE: Returned from init_algorithm() for ${ALGO_FILE}"
      # Note: No separate timing reported for this currently
  else
      log_event "LIFECYCLE: No init_algorithm() found in ${ALGO_FILE}."
  fi

  # --- Init Grid ---
  log_event "LIFECYCLE: Calling init_grid() for ${ALGO_FILE}..."
  local t_init_grid_start=$(date +%s.%N)
  init_grid
  local t_init_grid_end=$(date +%s.%N)
  log_event "LIFECYCLE: Returned from init_grid() for ${ALGO_FILE}"
  
  # --- Init Docs ---
  log_event "LIFECYCLE: Calling init_docs() for ${ALGO_FILE}..."
  local t_init_docs_start=$(date +%s.%N)
  init_docs
  local t_init_docs_end=$(date +%s.%N)
  log_event "LIFECYCLE: Returned from init_docs() for ${ALGO_FILE}"

  # Check if pages were actually loaded
  if [[ ${#PAGES[@]} -eq 0 ]]; then
      log_warn "LIFECYCLE WARN: Algorithm ${ALGO_FILE} did not provide any documentation pages via init_docs()."
  fi

  # --- Old Format Checks Removed --- 
  # AVAILABLE_FORMATS=()
  # AVAILABLE_FORMATS[ASCII]=1
  # if declare -F get_enhanced_char ...
  # if declare -F get_tiled_data ...

  STATUS_MESSAGE="Loaded ${ALGO_FILE}"
  log_event "Finished loading ${ALGO_FILE}. Timings: Source=$(echo "$t_sourced - $t_start" | bc -l), init_grid=$(echo "$t_init_grid_end - $t_init_grid_start" | bc -l), init_docs=$(echo "$t_init_docs_end - $t_init_docs_start" | bc -l)"
  return 0
}

# --- Load Control Definitions from Data File ---
# Reads keybindings.conf and populates global arrays:
#   - KEY_ACTIONS (associative array): Maps symbolic key names (e.g., 'q', 'UP', 'SPACE') to action functions.
#   - KEY_LABELS (associative array): Maps symbolic key names to descriptions.
#   - RAW_KEY_MAPPINGS (associative array): Maps symbolic key names to the full line from the config file.
#   - AVAILABLE_MODES (indexed array): Lists unique modes found in the definitions.
#   - CONTROL_KEYS (indexed array): Symbolic keys in the order they appear in the file, for display.
#   - CONTROL_LABELS (indexed array): Corresponding labels for display.
_load_control_definitions() {
    local controls_file="keybindings.conf"
    local line_num=0
    # Key here is the SYMBOLIC_KEY from the config file
    local key action description mode IFS='|'

    # Unset arrays first to avoid potential type conflicts
    unset KEY_ACTIONS KEY_LABELS RAW_KEY_MAPPINGS AVAILABLE_MODES CONTROL_KEYS CONTROL_LABELS

    # Re-declare global arrays to clear them and ensure correct types
    declare -gA KEY_ACTIONS=()
    declare -gA KEY_LABELS=()       # Associative: symbolic_key -> label
    declare -gA RAW_KEY_MAPPINGS=()
    declare -ga AVAILABLE_MODES=()
    declare -ga CONTROL_KEYS=()     # Indexed: order preserved for display
    declare -ga CONTROL_LABELS=()   # Indexed: order preserved for display

    if [[ -r "$controls_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            # Trim leading/trailing whitespace
            local trimmed_line; trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Skip empty lines and comments
            if [[ -z "$trimmed_line" || "$trimmed_line" =~ ^# ]]; then continue; fi

            # Parse the line using '|' as delimiter
            # Format: SYMBOLIC_KEY|ACTION|DESCRIPTION|MODE
            if ! IFS='|' read -r key action description mode <<< "$trimmed_line"; then
                 log_warn "LIFECYCLE WARN: Skipping malformed line $line_num in $controls_file: '$trimmed_line' (Expected SYMBOLIC_KEY|ACTION|DESCRIPTION|MODE)"
                 continue
            fi

            # Store raw mapping using the symbolic key
            RAW_KEY_MAPPINGS["$key"]="$trimmed_line"

            # Store action mapping using the symbolic key
            if [[ -n "$action" ]]; then
                KEY_ACTIONS["$key"]="$action"
            else
                log_warn "LIFECYCLE WARN: No action defined for key '$key' on line $line_num in $controls_file."
                continue # Skip if no action is defined
            fi

            # Store label mapping (associative) using the symbolic key
            if [[ -n "$description" ]]; then
                 KEY_LABELS["$key"]="$description"
            else
                log_warn "LIFECYCLE WARN: No description provided for key '$key' on line $line_num. Using placeholder."
                KEY_LABELS["$key"]="NO LABEL"
            fi

            # Store symbolic keys/labels in order for display overlay (indexed)
            CONTROL_KEYS+=( "$key" )
            CONTROL_LABELS+=( "${KEY_LABELS[$key]}" ) # Use the label we just stored

            # Track available modes
            if [[ -n "$mode" && ! " ${AVAILABLE_MODES[*]} " =~ " $mode " ]]; then
                AVAILABLE_MODES+=("$mode")
            fi

        done < "$controls_file"

        if [[ ${#KEY_ACTIONS[@]} -gt 0 ]]; then
            log_event "Successfully loaded ${#KEY_ACTIONS[@]} control definitions from $controls_file."
            log_event "Loaded ${#CONTROL_KEYS[@]} keys/labels for display."
            log_event "Available modes: ${AVAILABLE_MODES[*]}"
            return 0
        else
            log_error "FATAL: No valid control definitions loaded from keybindings.conf."
            return 1
        fi
    else
        log_error "FATAL: Cannot read control definitions file: $controls_file"
        return 1
    fi
}

# --- Terminal Setup ---
setup_terminal() {
  tput civis
  stty -echo # Disable input echoing
  log_event "Terminal setup: cursor hidden, echo disabled."
  # stty -echo # Add if needed
}

# --- Main Loop ---
main() {
  log_event "Engine main loop started"
  setup_terminal

  # --- Load Glyph & Color Maps FIRST ---
  if ! _load_color_map; then
      log_error "FATAL: Failed to load color definitions from $COLOR_CONFIG_FILE. Exiting."
      cleanup; exit 1;
  fi
  if ! _load_glyph_map; then
      log_error "FATAL: Failed to load glyph definitions from $GLYPH_CONFIG_FILE. Exiting."
      cleanup; exit 1;
  fi

  log_event "LIFECYCLE: Attempting to load control definitions..."
  # --- Load Controls ---
  if ! _load_control_definitions; then
      log_error "FATAL: _load_control_definitions failed."
      cleanup; exit 1;
  fi

  log_event "LIFECYCLE: Attempting to load initial algorithm (#$CURRENT_ALGO_INDEX)..."
  # --- Load Algo & Render ---
  if ! load_and_init_algorithm "$CURRENT_ALGO_INDEX"; then
    log_error "FATAL: Unable to load initial algorithm (see previous errors)."
    cleanup; exit 1;
  fi
  log_event "LIFECYCLE: Initial algorithm loaded. Attempting initial render..."
  render
  log_event "LIFECYCLE: Initial render complete. Entering main loop..."

  # --- Main loop logic using KEY_ACTIONS (populated by _load_control_definitions) ---
  while [[ $SHOULD_EXIT -eq 0 ]]; do
      # --- FPS Calculation (Temporarily Disabled for Performance Testing) ---
      # local frame_start_time=$(date +%s.%N)
      # ... (rest of FPS logic commented out) ...
      # --- End FPS Calculation ---

      log_event "LIFECYCLE LOOP: Top"
      local requires_render=0
      local exit_code=0

      # 1. Handle running state (algorithm update)
      if [[ $RUNNING -eq 1 ]]; then
          if declare -F update_algorithm &>/dev/null; then
              update_algorithm; exit_code=$?
              if [[ $exit_code -ne 0 ]]; then
                  RUNNING=0
                  STATUS_MESSAGE="Algorithm stopped (code $exit_code)"
                  log_event "$STATUS_MESSAGE"
                  requires_render=1
              else
                   # Continuous run doesn't trigger redraw unless algo requests it (how?)
                   # For now, assume running state always redraws
                   requires_render=1
              fi
          else
              STATUS_MESSAGE="Error: update_algorithm not found"
              echo "$STATUS_MESSAGE" >&2
              RUNNING=0
              requires_render=1
          fi
      fi

      # 2. Process User Input (using the new function)
      local input_processed_requires_render=0
      # Call _process_input and capture its return value (1 if redraw needed)
      if _process_input; then
          input_processed_requires_render=1
      fi
      log_event "LIFECYCLE LOOP: Input processed (redraw=$input_processed_requires_render)"

      # 3. Determine if Render is Needed
      # Render if running OR if input processing requested it
      if [[ $RUNNING -eq 1 || $input_processed_requires_render -eq 1 || $requires_render -eq 1 ]]; then
          log_event "LIFECYCLE LOOP: Render triggered (running=$RUNNING, input_req=$input_processed_requires_render, algo_req=$requires_render)"
          render
          log_event "LIFECYCLE LOOP: Render complete"
      fi

      # 4. Sleep if paused and no input detected (to prevent busy-waiting)
      # The timeout is now handled within _get_key_symbol inside _process_input
      # We might still want a small sleep here if not running to yield CPU
      [[ $RUNNING -eq 0 ]] && sleep 0.02

  done

  log_event "Engine main loop finished."
}

# --- Cleanup Function ---
cleanup() {
    log_event "!!!! LIFECYCLE: Cleanup function triggered... !!!!"
    tput cnorm || echo "CLEANUP WARN: tput cnorm failed." >&2   # Restore cursor visibility
    stty echo || echo "CLEANUP WARN: stty echo failed." >&2     # Explicitly restore echo
    stty sane || echo "CLEANUP WARN: stty sane failed." >&2     # Restore other terminal settings
    echo # Add a newline after finishing
    log_event "LIFECYCLE: Cleanup finished."
}

# --- Setup Trap Handler ---
setup_trap() {
    log_event "LIFECYCLE: Setting up trap handler..."
    trap 'cleanup' EXIT INT TERM QUIT HUP
    local trap_status=$?
    if [[ $trap_status -eq 0 ]]; then
        log_event "LIFECYCLE: Trap handler set successfully."
    else
        log_error "LIFECYCLE: Failed to set trap handler (status: $trap_status)!"
    fi
    return $trap_status
}
