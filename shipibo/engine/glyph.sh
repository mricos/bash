#!/usr/bin/env bash
# set -x # Enable command tracing for this script

# Shipibo Glyph Engine
# Manages mapping semantic cell states to rendering data (glyph, color, style, width)
# based on the current rendering mode.

# Source dependencies (needed for logging)
if [[ -f "./engine/logging.sh" ]]; then
    source "./engine/logging.sh"
else
    # Basic fallback logger if main logger not found
    log_event() { echo "[$(date +'%T')] [GLYPH LOG] $*"; }
    log_warn() { echo "[$(date +'%T')] [GLYPH WARN] $*" >&2; }
    log_error() { echo "[$(date +'%T')] [GLYPH ERROR] $*" >&2; }
    log_debug() { :; } # No-op debug
fi

# --- Global Data Structures ---
# RENDER_MAP[ "MODE|STATE" ] = "glyph=G|fg=FG_NAME|bg=BG_NAME|attr=A|width=W"
declare -gA RENDER_MAP
# COLOR_MAP[ "NAME" ] = "VALUE" (VALUE is numeric code or hex #RRGGBB)
declare -gA COLOR_MAP

# --- Configuration Files --- 
GLYPH_CONFIG_FILE="glyphs.conf"
COLOR_CONFIG_FILE="colors.conf"

# --- Load Color Map ---
_load_color_map() {
    log_event "GLYPH: Loading color map from $COLOR_CONFIG_FILE..."
    COLOR_MAP=() # Clear existing map
    local line_num=0
    local loaded_count=0

    if [[ ! -r "$COLOR_CONFIG_FILE" ]]; then
        log_error "GLYPH ERROR: Cannot read color config file: $COLOR_CONFIG_FILE"
        # Load minimal failsafe defaults
        COLOR_MAP["DEFAULT_FG"]=7
        COLOR_MAP["DEFAULT_BG"]=0
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        # Remove comments and leading/trailing whitespace
        local trimmed_line="${line%%#*}" # Remove comment
        trimmed_line="${trimmed_line#"${trimmed_line%%[![:space:]]*}"}" # Remove leading whitespace
        trimmed_line="${trimmed_line%"${trimmed_line##*[![:space:]]}"}" # Remove trailing whitespace

        if [[ -z "$trimmed_line" ]]; then continue; fi

        # Parse NAME=VALUE
        if [[ "$trimmed_line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Optionally trim value whitespace here too if needed:
            # value="${value#"${value%%[![:space:]]*}"}"
            # value="${value%"${value##*[![:space:]]}"}"
            COLOR_MAP["$name"]="$value"
            ((loaded_count++))
        else
            log_warn "GLYPH WARN: Skipping malformed line $line_num in $COLOR_CONFIG_FILE: '$trimmed_line'"
        fi
    done < "$COLOR_CONFIG_FILE"

    # Ensure basic defaults exist if not loaded
    [[ -z "${COLOR_MAP[DEFAULT_FG]}" ]] && COLOR_MAP["DEFAULT_FG"]=7
    [[ -z "${COLOR_MAP[DEFAULT_BG]}" ]] && COLOR_MAP["DEFAULT_BG"]=0

    log_event "GLYPH: Loaded $loaded_count color definitions from $COLOR_CONFIG_FILE."
    return 0
}

# --- Load Glyph Map ---
# Reads GLYPH_CONFIG_FILE and populates RENDER_MAP
_load_glyph_map() {
    log_event "GLYPH: Loading glyph map from $GLYPH_CONFIG_FILE..."
    RENDER_MAP=() # Clear existing map
    local line_num=0
    local loaded_count=0
    local default_loaded=0

    if [[ ! -r "$GLYPH_CONFIG_FILE" ]]; then
        log_error "GLYPH ERROR: Cannot read glyph config file: $GLYPH_CONFIG_FILE"
        # Optionally load hardcoded defaults here if file missing
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        # Remove comments and leading/trailing whitespace
        local trimmed_line="${line%%#*}" # Remove comment first
        trimmed_line="${trimmed_line#"${trimmed_line%%[![:space:]]*}"}" # Remove leading whitespace
        trimmed_line="${trimmed_line%"${trimmed_line##*[![:space:]]}"}" # Remove trailing whitespace
        # Skip empty lines
        if [[ -z "$trimmed_line" ]]; then continue; fi

        # Parse line: MODE | STATE | Key=Value | ...
        IFS='|' read -r mode state params_str <<<"$trimmed_line"
        # Trim whitespace from individual parts
        mode="${mode#"${mode%%[![:space:]]*}"}"; mode="${mode%"${mode##*[![:space:]]}"}"
        state="${state#"${state%%[![:space:]]*}"}"; state="${state%"${state##*[![:space:]]}"}"
        params_str="${params_str#"${params_str%%[![:space:]]*}"}"; params_str="${params_str%"${params_str##*[![:space:]]}"}"

        if [[ -z "$mode" || -z "$state" || -z "$params_str" ]]; then
            log_warn "GLYPH WARN: Skipping malformed line $line_num in $GLYPH_CONFIG_FILE: '$trimmed_line'"
            continue
        fi

        # Construct map key and store parameter string
        local map_key="${mode}|${state}"
        RENDER_MAP["$map_key"]="$params_str"
        ((loaded_count++))

        # Track if a default entry was loaded for any mode
        [[ "$state" == "DEFAULT" ]] && default_loaded=1

    done < "$GLYPH_CONFIG_FILE"

    if [[ $default_loaded -eq 0 ]]; then
        log_warn "GLYPH WARN: No 'DEFAULT' state found in $GLYPH_CONFIG_FILE. Fallback rendering might fail."
    fi

    log_event "GLYPH: Loaded $loaded_count entries from $GLYPH_CONFIG_FILE."
    # log_debug "GLYPH MAP DUMP: ${!RENDER_MAP[@]} => ${RENDER_MAP[@]}" # Very verbose
    return 0
}

# --- Get Render Data --- 
# Takes Semantic State name as $1.
# Outputs render data fields separated by pipe (|):
# GLYPH|FG_CMD|BG_CMD|ATTR_CMD|RESET_CMD|WIDTH
get_render_data() {
    local input_state="$1"
    local mode="${CURRENT_RENDER_MODE:-ASCII}"
    local params_str=""

    # --- Split input state: CHAR | COLOR_NAME --- 
    local state_char="$input_state"
    local state_color_name=""
    if [[ "$input_state" == *"|"* ]]; then
        state_char="${input_state%|*}"
        state_color_name="${input_state#*|}"
    fi
    # Default to space if char part is empty for some reason
    [[ -z "$state_char" ]] && state_char=" "

    # --- Lookup base definition using CHARACTER part of state, with fallbacks ---
    local potential_keys=(
        "${mode}|${state_char}"
        "${mode}|DEFAULT"
        "ASCII|DEFAULT"
    )
    params_str=""
    local found_key=""

    for key in "${potential_keys[@]}"; do
        # Check if the key exists in the map. Use -v for explicit check.
        if [[ -v RENDER_MAP["$key"] ]]; then
            params_str="${RENDER_MAP[$key]}"
            found_key="$key"
            # log_debug "GLYPH: Using definition from key '$found_key'"
            break
        fi
    done

    if [[ -z "$found_key" ]]; then # Check if we actually found a key
        log_warn "GLYPH WARN: No RENDER_MAP definition found for char '$state_char' (tried keys: ${potential_keys[*]}). Using defaults."
        # Use state_char as glyph directly with default colors/attr
        local default_fg_val="${COLOR_MAP[DEFAULT_FG]:-7}"
        local default_bg_val="${COLOR_MAP[DEFAULT_BG]:-0}"
        local default_fg_cmd=$(tput setaf "$default_fg_val" 2>/dev/null || echo "")
        local default_bg_cmd=$(tput setab "$default_bg_val" 2>/dev/null || echo "")
        local reset_cmd=$(tput sgr0)
        echo "${state_char}|${default_fg_cmd}|${default_bg_cmd}||${reset_cmd}|1"
        return 1 # Indicate failure to find definition
    fi

    # --- Parse Parameters from RENDER_MAP entry --- 
    # Initialize defaults, glyph will be overridden by state_char later
    local glyph="?" fg_name="DEFAULT_FG" bg_name="DEFAULT_BG" attr="normal" width=1
    
    # --- Faster parsing using parameter expansion --- 
    local pair key value
    IFS='|' read -ra pairs <<< "$params_str" # Split into pairs array
    for pair in "${pairs[@]}"; do
        # Split pair by '='. Use %%* to remove everything after first =
        key="${pair%%=*}"
        # Use #* to remove everything before and including first =
        value="${pair#*=}"
        # Basic trimming (remove leading/trailing space if glyphs.conf is messy)
        # key=$(echo "$key" | xargs) # Avoid echo/xargs if possible
        # value=$(echo "$value" | xargs)
        case "$key" in
            glyph) glyph="$value" ;;
            fg)    fg_name="$value" ;;
            bg)    bg_name="$value" ;;
            attr)  attr="$value" ;;
            width) width="$value" ;;
        esac
    done
    # --- End Faster Parsing ---

    # Override glyph with the actual character passed in state_char
    glyph="$state_char"

    # Override fg_name if a specific color name was passed via state_color_name
    if [[ -n "$state_color_name" ]]; then
        # --- DEBUG --- 
        echo "DEBUG GLYPH: Checking color name: '$state_color_name'" >&2
        # --- END DEBUG ---
        # Check if the provided color name actually exists in COLOR_MAP
        if [[ -v COLOR_MAP["$state_color_name"] ]]; then
            fg_name="$state_color_name"
            # Optional: Maybe also default background if specific FG is set?
            # bg_name="DEFAULT_BG" 
        else
            log_warn "GLYPH WARN: Algorithm requested color '$state_color_name' (from state '$input_state') but it is not defined in $COLOR_CONFIG_FILE. Using original FG: $fg_name"
        fi
    fi

    # --- Lookup Color Values --- 
    local fg_val="${COLOR_MAP[$fg_name]:-${COLOR_MAP[DEFAULT_FG]:-7}}"
    local bg_val="${COLOR_MAP[$bg_name]:-${COLOR_MAP[DEFAULT_BG]:-0}}"

    # --- Generate tput commands --- 
    local fg_cmd="" bg_cmd="" attr_cmd="" reset_cmd="$(tput sgr0)"

    # Foreground (Currently only handling numeric codes)
    if [[ "$fg_val" =~ ^[0-9]+$ || "$fg_val" == "-1" ]]; then 
        if [[ $fg_val -ge 0 ]]; then
             fg_cmd=$(tput setaf $fg_val 2>/dev/null || echo "")
        fi # -1 means default, so no command needed
    elif [[ "$fg_val" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        # TODO: Add TrueColor Hex support here later
        log_warn "GLYPH: Hex color '$fg_val' for $fg_name not yet supported. Using default."
    else
        log_warn "GLYPH: Invalid color value '$fg_val' for $fg_name. Using default."
    fi
    
    # Background (Currently only handling numeric codes)
    if [[ "$bg_val" =~ ^[0-9]+$ || "$bg_val" == "-1" ]]; then
        if [[ $bg_val -ge 0 ]]; then
             bg_cmd=$(tput setab $bg_val 2>/dev/null || echo "")
        fi # -1 means default
    elif [[ "$bg_val" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        # TODO: Add TrueColor Hex support here later
        log_warn "GLYPH: Hex color '$bg_val' for $bg_name not yet supported. Using default."
    else
        log_warn "GLYPH: Invalid color value '$bg_val' for $bg_name. Using default."
    fi
    
    # Attribute (Lookup remains the same)
    case "$attr" in
        bold|dim|rev|smul|rmul|sgr0|blink|invis|prot|smso|rmso|smul|rmul) 
            attr_cmd=$(tput "$attr" 2>/dev/null || echo "")
            ;;
        normal) 
            attr_cmd=$reset_cmd; reset_cmd="" 
            ;;
        none|"") 
            attr_cmd=""
            ;;
        *) 
            log_warn "GLYPH WARN: Unknown attribute '$attr' for $found_key"
            attr_cmd=""
            ;;
    esac

    # Output fields separated by pipe
    echo "${glyph}|${fg_cmd}|${bg_cmd}|${attr_cmd}|${reset_cmd}|${width}"
    return 0
} 