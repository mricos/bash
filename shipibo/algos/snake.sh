# --- Snake Path Algorithm ---
# Moves a fixed-length snake across the Base Grid.

# --- Algorithm Specific State ---
# Direction constants
DIRECTION_RIGHT=0
DIRECTION_DOWN=1
DIRECTION_LEFT=2
DIRECTION_UP=3

# Snake properties
declare -ga SNAKE_POSITIONS=()         # Array of positions "y,x", head is index 0
declare -g SNAKE_DIRECTION=$DIRECTION_RIGHT
declare -g SNAKE_LENGTH=5
declare -g SNAKE_MOVES=0
declare -g STRAIGHT_COUNT=0            # Tracks consecutive straight moves

# --- Engine Hook Functions ---

# Initialize the Base Grid (grid, collapsed) and snake state
init_grid() {
    # Clear Base Grid
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            grid[$key]=""       # No symbol initially
            collapsed[$key]=0 # Not collapsed
        done
    done

    # Reset snake state
    local start_y=$((ROWS/2))
    local start_x=$((COLS/3))
    SNAKE_DIRECTION=$DIRECTION_RIGHT
    SNAKE_POSITIONS=()
    STRAIGHT_COUNT=0
    SNAKE_MOVES=0

    # Create initial snake body positions (head at index 0)
    for ((i=0; i<SNAKE_LENGTH; i++)); do
        local pos_x=$((start_x - i))
        if ((pos_x >= 0)); then
            SNAKE_POSITIONS+=("$start_y,$pos_x")
        else
            break # Stop if we hit the edge during init
        fi
    done
    # Ensure snake has at least the head if possible
     if [[ ${#SNAKE_POSITIONS[@]} -eq 0 && $start_x -ge 0 && $start_y -ge 0 && $start_y -lt $ROWS ]]; then
        SNAKE_POSITIONS=("$start_y,$start_x")
     fi

    # Initial draw onto the Base Grid
    _draw_snake_to_grid
    return 0
}

# Initialize documentation pages
init_docs() {
    PAGES=() # Clear/initialize pages array
    PAGES+=("$(cat <<'EOF'
SNAKE PATH ALGORITHM (Page 1/3)
-------------------------------
Creates a continuous snake path of
fixed length (5 segments) that
meanders through the grid. ASCII only.

Uses box-drawing characters: ─│┌┐└┘
or simple +/-| for segments.
EOF
)")
    PAGES+=("$(cat <<'EOF'
HOW IT WORKS (Page 2/3)
-----------------------
The snake tries to move straight but
has a chance to turn left or right.
The chance increases if it has been
moving straight for a while or if it
approaches an edge. Avoids self-collision.
EOF
)")
    PAGES+=("$(cat <<'EOF'
TECHNICAL DETAILS (Page 3/3)
--------------------------
Internal state:
- SNAKE_POSITIONS: Array of "y,x" coords
- SNAKE_DIRECTION: 0-3 (R,D,L,U)
- SNAKE_LENGTH: Fixed at 5

Uses _get_symbol or _get_symbol_box
to calculate connector character.
EOF
)")
}


# Update the snake's state and the Base Grid for one step
update_algorithm() {
    ((SNAKE_MOVES++))

    # 1. Choose next direction (avoids walls and self)
    local new_direction=$(_choose_next_direction)

    # Check if trapped (no valid move)
    if [[ $new_direction -eq -1 ]]; then
        STATUS_MESSAGE="Snake trapped! Moves: $SNAKE_MOVES"
        # No need to draw again, state hasn't changed
        return 1 # Signal trapped state to engine
    fi
    SNAKE_DIRECTION=$new_direction

    # 2. Calculate new head position
    local head="${SNAKE_POSITIONS[0]}"
    local head_y="${head%,*}"
    local head_x="${head#*,}"
    local new_y=$head_y
    local new_x=$head_x

    case $SNAKE_DIRECTION in
        $DIRECTION_RIGHT) ((new_x++)) ;;
        $DIRECTION_DOWN)  ((new_y++)) ;;
        $DIRECTION_LEFT)  ((new_x--)) ;;
        $DIRECTION_UP)    ((new_y--)) ;;
    esac

    # 3. Check if move is valid (redundant check, _choose_next_direction handles this)
     if ! _is_valid_move "$new_y" "$new_x"; then
        # This case indicates an issue in _choose_next_direction if reached
        STATUS_MESSAGE="Snake stopped! Invalid move. Moves: $SNAKE_MOVES"
        _draw_snake_to_grid # Draw final state before stopping
        return 1 # Signal to stop
     fi

    # 4. Update Snake Position Array
    # Clear the grid cell where the tail *was* before moving
    local tail_index=$((${#SNAKE_POSITIONS[@]} - 1))
    if [[ $tail_index -ge 0 ]]; then # Ensure snake has segments
        local tail="${SNAKE_POSITIONS[$tail_index]}"
        if [[ -n "$tail" ]]; then
            grid[$tail]=""
            collapsed[$tail]=0
        fi
    fi

    # Add new head position to the *beginning* of the array
    SNAKE_POSITIONS=("$new_y,$new_x" "${SNAKE_POSITIONS[@]}")

    # Remove the tail if snake exceeds max length (it will be last element now)
    if [[ ${#SNAKE_POSITIONS[@]} -gt $SNAKE_LENGTH ]]; then
        SNAKE_POSITIONS=("${SNAKE_POSITIONS[@]:0:$SNAKE_LENGTH}") # Slice array
    fi

    # 5. Draw updated snake onto the Base Grid
    _draw_snake_to_grid

    STATUS_MESSAGE="Len:$SNAKE_LENGTH|Mov:$SNAKE_MOVES|Str:$STRAIGHT_COUNT|Dir:$SNAKE_DIRECTION"
    return 0 # Continue running
}

# --- Internal Helper Functions ---

# Calculate the appropriate symbol using simple ASCII +-|
_get_symbol() {
    local prev_y=$1 prev_x=$2 curr_y=$3 curr_x=$4 next_y=$5 next_x=$6
    local symbol="?" # Default fallback

    # Handle Head (no prev segment)
    if [[ $prev_y -eq -1 ]]; then
        if [[ $next_y -eq -1 ]]; then symbol="O"; # Single segment snake
        elif [[ $curr_y -eq $next_y ]]; then symbol="-"; # Horizontal end
        else symbol="|"; fi # Vertical end
        echo "$symbol"; return
    fi
    # Handle Tail (no next segment)
    if [[ $next_y -eq -1 ]]; then
        if [[ $curr_y -eq $prev_y ]]; then symbol="-"; # Horizontal end
        else symbol="|"; fi # Vertical end
        echo "$symbol"; return
    fi

    # Middle segments
    local from_head_dx=$((curr_x - prev_x)); local from_head_dy=$((curr_y - prev_y))
    local to_tail_dx=$((next_x - curr_x)); local to_tail_dy=$((next_y - curr_y))

    # Straight horizontal?
    if [[ $from_head_dy -eq 0 && $to_tail_dy -eq 0 ]]; then symbol="-"; echo "$symbol"; return; fi
    # Straight vertical?
    if [[ $from_head_dx -eq 0 && $to_tail_dx -eq 0 ]]; then symbol="|"; echo "$symbol"; return; fi

    # Corners (Use '+' for all corners in this simple version)
    symbol="+"
    echo "$symbol"
}

# Calculate the appropriate symbol using Box Drawing characters
_get_symbol_box() {
    local prev_y=$1 prev_x=$2 curr_y=$3 curr_x=$4 next_y=$5 next_x=$6

    # Handle Head (no prev segment, connected to 'next' towards tail)
    if [[ $prev_y -eq -1 ]]; then
        if [[ $next_y -eq -1 ]]; then echo "o"; return; fi # Single segment snake
        # Head looks like end of line segment pointing towards next segment
        if [[ $curr_y -eq $next_y ]]; then # Next is Left or Right
             if (( curr_x > next_x )); then echo "▷"; else echo "◁"; fi # Pointing Left or Right
        else # Next is Up or Down
             if (( curr_y > next_y )); then echo "▽"; else echo "△"; fi # Pointing Up or Down
        fi
        return
    fi
    # Handle Tail (no next segment, connected to 'prev' towards head)
     if [[ $next_y -eq -1 ]]; then
         # Tail looks like end of line segment pointing back towards previous segment
         if [[ $curr_y -eq $prev_y ]]; then # Prev is Left or Right
             if (( curr_x > prev_x )); then echo "◁"; else echo "▷"; fi # Pointing Right or Left
         else # Prev is Up or Down
             if (( curr_y > prev_y )); then echo "△"; else echo "▽"; fi # Pointing Down or Up
         fi
         return
     fi


    # Middle segments - determine relative positions
    local from_head_dx=$((curr_x - prev_x)) # Vector from previous (head side)
    local from_head_dy=$((curr_y - prev_y))
    local to_tail_dx=$((next_x - curr_x))   # Vector to next (tail side)
    local to_tail_dy=$((next_y - curr_y))

    # Straight horizontal? (Came from L/R, going to R/L)
    if [[ $from_head_dy -eq 0 && $to_tail_dy -eq 0 ]]; then echo "─"; return; fi
    # Straight vertical? (Came from U/D, going to D/U)
    if [[ $from_head_dx -eq 0 && $to_tail_dx -eq 0 ]]; then echo "│"; return; fi

    # Corners - Combine incoming (from head side) and outgoing (to tail side) vectors
    # Example: Came from Up (dy=-1), Going Right (dx=1 relative to current = next is right) -> CORNER_TR = ┐
    if [[ $from_head_dy -eq -1 && $to_tail_dx -eq 1 ]];  then echo "└"; return; fi # Up -> Right = L
    if [[ $from_head_dx -eq -1 && $to_tail_dy -eq 1 ]];  then echo "┐"; return; fi # Left -> Down = TR

    if [[ $from_head_dy -eq -1 && $to_tail_dx -eq -1 ]]; then echo "┘"; return; fi # Up -> Left = J
    if [[ $from_head_dx -eq 1 && $to_tail_dy -eq 1 ]];  then echo "┌"; return; fi # Right -> Down = TL

    if [[ $from_head_dy -eq 1 && $to_tail_dx -eq 1 ]];  then echo "┌"; return; fi # Down -> Right = TL
    if [[ $from_head_dx -eq -1 && $to_tail_dy -eq -1 ]]; then echo "┘"; return; fi # Left -> Up = J

    if [[ $from_head_dy -eq 1 && $to_tail_dx -eq -1 ]]; then echo "┐"; return; fi # Down -> Left = TR
    if [[ $from_head_dx -eq 1 && $to_tail_dy -eq -1 ]]; then echo "└"; return; fi # Right -> Up = L

    # Fallback for any unexpected combination
    echo "?"
}


# Draws the current snake state onto the global Base Grid (grid, collapsed)
_draw_snake_to_grid() {
    # Re-draw all segments based on current SNAKE_POSITIONS
    for ((i=0; i<${#SNAKE_POSITIONS[@]}; i++)); do
        local curr="${SNAKE_POSITIONS[$i]}"
        if [[ -z "$curr" ]]; then continue; fi # Skip if position somehow empty

        local curr_y="${curr%,*}"
        local curr_x="${curr#*,}"

        # Identify coordinates of neighbors relative to position in array (0=head)
        # prev_coord = segment closer to HEAD (index i-1)
        # next_coord = segment closer to TAIL (index i+1)
        local prev_coord_y=-1; local prev_coord_x=-1 # Towards head
        local next_coord_y=-1; local next_coord_x=-1 # Towards tail

        if (( i > 0 )); then # Check if segment towards head exists
            local prev_seg="${SNAKE_POSITIONS[$((i-1))]}"
            if [[ -n "$prev_seg" ]]; then prev_coord_y="${prev_seg%,*}"; prev_coord_x="${prev_seg#*,}"; fi
        fi
        if (( i < ${#SNAKE_POSITIONS[@]} - 1 )); then # Check if segment towards tail exists
            local next_seg="${SNAKE_POSITIONS[$((i+1))]}"
            if [[ -n "$next_seg" ]]; then next_coord_y="${next_seg%,*}"; next_coord_x="${next_seg#*,}"; fi
        fi

        # Calculate symbol using helper function based on adjacent segments
        # Order for _get_symbol: prev(head side), current, next(tail side)
        # local symbol=$(_get_symbol "$prev_coord_y" "$prev_coord_x" "$curr_y" "$curr_x" "$next_coord_y" "$next_coord_x")
        local symbol=$(_get_symbol_box "$prev_coord_y" "$prev_coord_x" "$curr_y" "$curr_x" "$next_coord_y" "$next_coord_x")


        # Place symbol on the Base Grid
        if [[ -z "$symbol" ]]; then
             grid["$curr_y,$curr_x"]="?" # Fallback if symbol calculation failed
        else
             grid["$curr_y,$curr_x"]="$symbol"
        fi
        collapsed["$curr_y,$curr_x"]=1
    done
}


# Choose next direction, avoid walls/self, with controlled turn frequency
_choose_next_direction() {
    local current_dir=$SNAKE_DIRECTION
    local head="${SNAKE_POSITIONS[0]}"
     # Handle case where snake hasn't initialized fully
     if [[ -z "$head" ]]; then return -1; fi
    local head_y="${head%,*}"
    local head_x="${head#*,}"

    # --- Check validity of potential moves: Straight, Left, Right ---
    local -A valid_next_pos # Store valid "dir_index"="y,x"
    local -a possible_dirs=() # Array of direction indices

    # Check straight ahead
    local s_y=$head_y; local s_x=$head_x
    case $current_dir in $DIRECTION_RIGHT) ((s_x++));; $DIRECTION_DOWN) ((s_y++));; $DIRECTION_LEFT) ((s_x--));; $DIRECTION_UP) ((s_y--));; esac
    if _is_valid_move "$s_y" "$s_x"; then valid_next_pos[$current_dir]="$s_y,$s_x"; possible_dirs+=($current_dir); fi

    # Check left turn (relative to current direction)
    local left_dir=$(( (current_dir + 3) % 4 )) # +3 for left turn
    local l_y=$head_y; local l_x=$head_x
    case $left_dir in $DIRECTION_RIGHT) ((l_x++));; $DIRECTION_DOWN) ((l_y++));; $DIRECTION_LEFT) ((l_x--));; $DIRECTION_UP) ((l_y--));; esac
    if _is_valid_move "$l_y" "$l_x"; then valid_next_pos[$left_dir]="$l_y,$l_x"; possible_dirs+=($left_dir); fi

    # Check right turn (relative to current direction)
    local right_dir=$(( (current_dir + 1) % 4 )) # +1 for right turn
    local r_y=$head_y; local r_x=$head_x
    case $right_dir in $DIRECTION_RIGHT) ((r_x++));; $DIRECTION_DOWN) ((r_y++));; $DIRECTION_LEFT) ((r_x--));; $DIRECTION_UP) ((r_y--));; esac
    if _is_valid_move "$r_y" "$r_x"; then valid_next_pos[$right_dir]="$r_y,$r_x"; possible_dirs+=($right_dir); fi

    # --- Decide which direction to take ---
    if [[ ${#possible_dirs[@]} -eq 0 ]]; then return -1; fi # Trapped

    local can_go_straight=0; [[ -v "valid_next_pos[$current_dir]" ]] && can_go_straight=1

    local turn_chance=15 # Base chance
    if [[ $can_go_straight -eq 0 ]]; then turn_chance=100 # Must turn
    elif (( (current_dir == DIRECTION_RIGHT && head_x >= COLS-2) || (current_dir == DIRECTION_LEFT && head_x <= 1) || (current_dir == DIRECTION_DOWN && head_y >= ROWS-2) || (current_dir == DIRECTION_UP && head_y <= 1) )); then turn_chance=85 # Near edge
    elif (( STRAIGHT_COUNT > 5 )); then turn_chance=70
    elif (( STRAIGHT_COUNT > 3 )); then turn_chance=40; fi

    local chosen_dir=-1
    if [[ $can_go_straight -eq 1 ]] && (( RANDOM % 100 >= turn_chance )); then
        chosen_dir=$current_dir; ((STRAIGHT_COUNT++))
    else
        local -a turn_options=()
        [[ -v "valid_next_pos[$left_dir]" ]] && turn_options+=($left_dir)
        [[ -v "valid_next_pos[$right_dir]" ]] && turn_options+=($right_dir)
        if [[ ${#turn_options[@]} -gt 0 ]]; then chosen_dir=${turn_options[$((RANDOM % ${#turn_options[@]}))]}; STRAIGHT_COUNT=0;
        elif [[ $can_go_straight -eq 1 ]]; then chosen_dir=$current_dir; ((STRAIGHT_COUNT++)); # Forced straight
        else chosen_dir="-1"; fi # Trapped if must turn but no valid turns
    fi
    echo $chosen_dir
}

# Helper to check if coordinate y,x is valid (in bounds, not snake body except tail)
_is_valid_move() {
    local y=$1; local x=$2
    if (( y < 0 || y >= ROWS || x < 0 || x >= COLS )); then return 1; fi
    # Check self collision (ignore tail segment - index length-1)
    local tail_index=$((${#SNAKE_POSITIONS[@]} - 1))
    for ((i=0; i<tail_index; i++)); do # Loop up to element *before* tail
        if [[ "${SNAKE_POSITIONS[$i]}" == "$y,$x" ]]; then return 1; fi
    done
    return 0 # Valid move
}

