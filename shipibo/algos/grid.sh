#!/usr/bin/env bash

# --- Snake Path Algorithm ---
# A simple algorithm that creates meandering snake-like paths with spaces

# Define pages of information about this algorithm
PAGES=(
    "SNAKE PATH ALGORITHM

Creates a continuous snake path
with exactly 5 segments that
meanders through the grid.

The snake maintains its length as
it moves across the grid and stops
if it hits an edge."
    
    "HOW IT WORKS

The algorithm uses a simple approach
to maintain a fixed-length snake.

The snake includes exactly 5 connected
segments with the tail disappearing as
the head advances."
    
    "TECHNICAL DETAILS

The snake always forms a continuous
path with proper connections.

Turn frequency is controlled to
create natural-looking movement."
)

# Export the PAGES array for the engine to use
export PAGES

# Symbol set for snake
SYMBOLS=("─" "│" "┌" "┐" "└" "┘" " ")

# Direction constants
DIRECTION_RIGHT=0
DIRECTION_DOWN=1  
DIRECTION_LEFT=2
DIRECTION_UP=3

# Snake properties
declare -g SNAKE_POSITIONS=()  # Array of positions "y,x"
declare -g SNAKE_DIRECTION=$DIRECTION_RIGHT
declare -g SNAKE_LENGTH=5
declare -g SNAKE_MOVES=0
declare -g STRAIGHT_COUNT=0

# Initialize rules (empty for compatibility)
init_rules() {
    # Minimal rules for engine compatibility
    rules=()
    rules["─_left"]="─ ┘ ┐"
    rules["─_right"]="─ └ ┌"
    rules["│_up"]="│ └ ┘"
    rules["│_down"]="│ ┌ ┐"
    rules["┌_down"]="│"
    rules["┌_right"]="─"
    rules["┐_down"]="│"
    rules["┐_left"]="─"
    rules["└_up"]="│"
    rules["└_right"]="─"
    rules["┘_up"]="│"
    rules["┘_left"]="─"
    rules[" _left"]=" "
    rules[" _right"]=" "
    rules[" _up"]=" "
    rules[" _down"]=" "
    return 0
}

# Initialize the grid with a snake of length 5
init_grid() {
    # Clear grid
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            grid[$key]=""
            collapsed[$key]=0
            possibilities[$key]="${SYMBOLS[*]}" # Needed for engine display
        done
    done
    
    # Start with a horizontal snake
    local start_y=$((ROWS/2))
    local start_x=$((COLS/3))
    SNAKE_DIRECTION=$DIRECTION_RIGHT
    SNAKE_POSITIONS=()
    STRAIGHT_COUNT=0
    SNAKE_MOVES=0
    
    # Create initial positions - start with head, move left for 5 segments
    for ((i=0; i<SNAKE_LENGTH; i++)); do
        local pos_x=$((start_x - i))
        if ((pos_x >= 0)); then
            SNAKE_POSITIONS+=("$start_y,$pos_x")
        fi
    done
    
    # Draw the initial snake
    draw_snake
    
    return 0
}

# Calculate the appropriate symbol based on 3 points
get_symbol() {
    local prev_y=$1
    local prev_x=$2
    local curr_y=$3
    local curr_x=$4
    local next_y=$5
    local next_x=$6
    
    # For head or tail (edge cases)
    if [[ $prev_y -eq -1 || $next_y -eq -1 ]]; then
        # Determine direction based on the one point we have
        if [[ $prev_y -eq -1 ]]; then
            # This is the head - use next point
            if [[ $curr_y -eq $next_y ]]; then
                echo "─" # Horizontal
            else
                echo "│" # Vertical
            fi
        else
            # This is the tail - use previous point
            if [[ $curr_y -eq $prev_y ]]; then
                echo "─" # Horizontal
            else
                echo "│" # Vertical
            fi
        fi
        return
    fi
    
    # For middle segments - need to determine if it's a straight or corner
    
    # If both previous and next are on same horizontal line
    if [[ $prev_y -eq $curr_y && $curr_y -eq $next_y ]]; then
        echo "─" # Horizontal line
        return
    fi
    
    # If both previous and next are on same vertical line
    if [[ $prev_x -eq $curr_x && $curr_x -eq $next_x ]]; then
        echo "│" # Vertical line
        return
    fi
    
    # Corner cases - determine based on relative positions
    if [[ $prev_x -lt $curr_x && $next_y -lt $curr_y ]]; then
        echo "┘" # Right to Up
    elif [[ $prev_x -lt $curr_x && $next_y -gt $curr_y ]]; then
        echo "┐" # Right to Down
    elif [[ $prev_x -gt $curr_x && $next_y -lt $curr_y ]]; then
        echo "└" # Left to Up
    elif [[ $prev_x -gt $curr_x && $next_y -gt $curr_y ]]; then
        echo "┌" # Left to Down
    elif [[ $prev_y -lt $curr_y && $next_x -lt $curr_x ]]; then
        echo "┘" # Down to Left
    elif [[ $prev_y -lt $curr_y && $next_x -gt $curr_x ]]; then
        echo "└" # Down to Right
    elif [[ $prev_y -gt $curr_y && $next_x -lt $curr_x ]]; then
        echo "┐" # Up to Left
    elif [[ $prev_y -gt $curr_y && $next_x -gt $curr_x ]]; then
        echo "┌" # Up to Right
    else
        # Fallback
        echo "─"
    fi
}

# Draw the snake on the grid
draw_snake() {
    # Clear existing snake (excluding spaces)
    for pos in "${SNAKE_POSITIONS[@]}"; do
        if [[ -n "$pos" ]]; then # Check if position is not empty
            grid[$pos]=""
            collapsed[$pos]=0
        fi
    done
    # Also clear the potential next position of the tail, which might have been the head
    local potential_tail="${SNAKE_POSITIONS[${#SNAKE_POSITIONS[@]}-1]}"
    if [[ -n "$potential_tail" ]]; then
        grid[$potential_tail]=""
        collapsed[$potential_tail]=0
    fi

    # Process each segment
    for ((i=0; i<${#SNAKE_POSITIONS[@]}; i++)); do
        local curr="${SNAKE_POSITIONS[$i]}"
        if [[ -z "$curr" ]]; then continue; fi # Skip empty positions if any
        
        local curr_y="${curr%,*}"
        local curr_x="${curr#*,}"
        
        local prev_y=-1
        local prev_x=-1
        local next_y=-1
        local next_x=-1
        
        # Get previous position if available
        if ((i > 0)); then
            local prev="${SNAKE_POSITIONS[$((i-1))]}"
             if [[ -n "$prev" ]]; then
                prev_y="${prev%,*}"
                prev_x="${prev#*,}"
            fi
        fi
        
        # Get next position if available
        if ((i < ${#SNAKE_POSITIONS[@]}-1)); then
            local next="${SNAKE_POSITIONS[$((i+1))]}"
            if [[ -n "$next" ]]; then
                next_y="${next%,*}"
                next_x="${next#*,}"
            fi
        fi
        
        # Calculate symbol
        local symbol=$(get_symbol "$prev_y" "$prev_x" "$curr_y" "$curr_x" "$next_y" "$next_x")
        
        # Place symbol
        grid["$curr_y,$curr_x"]="$symbol"
        collapsed["$curr_y,$curr_x"]=1
    done
    
    # Add spaces around the snake (optional visual enhancement)
    for pos in "${SNAKE_POSITIONS[@]}"; do
         if [[ -z "$pos" ]]; then continue; fi
         local y="${pos%,*}"
         local x="${pos#*,}"
        
        # Add spaces around this segment
        for dy in -1 0 1; do
            for dx in -1 0 1; do
                if [[ $dy -eq 0 && $dx -eq 0 ]]; then continue; fi
                
                local ny=$((y + dy))
                local nx=$((x + dx))
                
                # Check bounds
                if (( ny >= 0 && ny < ROWS && nx >= 0 && nx < COLS )); then
                    # Only place space if cell is not already occupied by snake
                    local is_snake=0
                    for s_pos in "${SNAKE_POSITIONS[@]}"; do
                        if [[ "$s_pos" == "$ny,$nx" ]]; then
                            is_snake=1
                            break
                        fi
                    done
                    
                    if [[ $is_snake -eq 0 && ${collapsed["$ny,$nx"]} -eq 0 ]]; then
                        if (( RANDOM % 100 < 20 )); then # Lower chance for spaces
                            grid["$ny,$nx"]=" "
                            collapsed["$ny,$nx"]=1
                        fi
                    fi
                fi
            done
        done
    done
}

# Choose next direction with controlled turn frequency
choose_direction() {
    local curr_dir=$SNAKE_DIRECTION
    
    # Get head position
    local head="${SNAKE_POSITIONS[0]}"
    local head_y="${head%,*}"
    local head_x="${head#*,}"
    
    # Check potential next move
    local next_y=$head_y
    local next_x=$head_x
    case $curr_dir in
        $DIRECTION_RIGHT) next_x=$((head_x + 1)) ;;
        $DIRECTION_DOWN)  next_y=$((head_y + 1)) ;;
        $DIRECTION_LEFT)  next_x=$((head_x - 1)) ;;
        $DIRECTION_UP)    next_y=$((head_y - 1)) ;;
    esac

    # Check if next position is valid (within bounds and not self)
    local is_valid=1
    if (( next_x < 0 || next_x >= COLS || next_y < 0 || next_y >= ROWS )); then
        is_valid=0
    else
        # Check for self-collision (except tail which will disappear)
        for ((i=0; i<${#SNAKE_POSITIONS[@]}-1; i++)); do
            if [[ "${SNAKE_POSITIONS[$i]}" == "$next_y,$next_x" ]]; then
                is_valid=0
                break
            fi
        done
    fi

    # Determine if we MUST turn
    local must_turn=0
    if [[ $is_valid -eq 0 ]]; then
        must_turn=1
    fi

    # Regular turn logic based on straight count and edge proximity
    local turn_chance=15 # Base turn chance
    if [[ $must_turn -eq 1 ]]; then
        turn_chance=100 # Force turn
    elif (( (curr_dir == DIRECTION_RIGHT && head_x >= COLS-2) || 
             (curr_dir == DIRECTION_LEFT && head_x <= 1) ||
             (curr_dir == DIRECTION_DOWN && head_y >= ROWS-2) ||
             (curr_dir == DIRECTION_UP && head_y <= 1) )); then
        turn_chance=85 # High chance near edge
    elif (( STRAIGHT_COUNT > 5 )); then
        turn_chance=70 # High chance after going straight
    elif (( STRAIGHT_COUNT > 3 )); then
        turn_chance=40 # Medium chance
    fi

    # Decide if we should turn
    if (( RANDOM % 100 < turn_chance )); then
        # Get valid turn options
        local valid_dirs=()
        local left_dir=$(( (curr_dir + 1) % 4 ))
        local right_dir=$(( (curr_dir + 3) % 4 ))

        # Check left turn
        local try_y=$head_y; local try_x=$head_x
        case $left_dir in
            $DIRECTION_RIGHT) try_x=$((head_x + 1)) ;;
            $DIRECTION_DOWN)  try_y=$((head_y + 1)) ;;
            $DIRECTION_LEFT)  try_x=$((head_x - 1)) ;;
            $DIRECTION_UP)    try_y=$((head_y - 1)) ;;
        esac
        local left_is_valid=1
        if (( try_x < 0 || try_x >= COLS || try_y < 0 || try_y >= ROWS )); then left_is_valid=0; fi
        if [[ $left_is_valid -eq 1 ]]; then
            for ((i=0; i<${#SNAKE_POSITIONS[@]}-1; i++)); do if [[ "${SNAKE_POSITIONS[$i]}" == "$try_y,$try_x" ]]; then left_is_valid=0; break; fi; done
        fi
        if [[ $left_is_valid -eq 1 ]]; then valid_dirs+=($left_dir); fi

        # Check right turn
        try_y=$head_y; try_x=$head_x
        case $right_dir in
            $DIRECTION_RIGHT) try_x=$((head_x + 1)) ;;
            $DIRECTION_DOWN)  try_y=$((head_y + 1)) ;;
            $DIRECTION_LEFT)  try_x=$((head_x - 1)) ;;
            $DIRECTION_UP)    try_y=$((head_y - 1)) ;;
        esac
        local right_is_valid=1
        if (( try_x < 0 || try_x >= COLS || try_y < 0 || try_y >= ROWS )); then right_is_valid=0; fi
        if [[ $right_is_valid -eq 1 ]]; then
            for ((i=0; i<${#SNAKE_POSITIONS[@]}-1; i++)); do if [[ "${SNAKE_POSITIONS[$i]}" == "$try_y,$try_x" ]]; then right_is_valid=0; break; fi; done
        fi
        if [[ $right_is_valid -eq 1 ]]; then valid_dirs+=($right_dir); fi

        # Choose a valid turn
        if [[ ${#valid_dirs[@]} -gt 0 ]]; then
            curr_dir=${valid_dirs[$((RANDOM % ${#valid_dirs[@]}))]}
            STRAIGHT_COUNT=0 # Reset straight count on turn
        elif [[ $must_turn -eq 1 ]]; then
             # If forced turn and no valid L/R, try opposite direction
             local opposite_dir=$(( (SNAKE_DIRECTION + 2) % 4 ))
             try_y=$head_y; try_x=$head_x
             case $opposite_dir in
                $DIRECTION_RIGHT) try_x=$((head_x + 1)) ;;
                $DIRECTION_DOWN)  try_y=$((head_y + 1)) ;;
                $DIRECTION_LEFT)  try_x=$((head_x - 1)) ;;
                $DIRECTION_UP)    try_y=$((head_y - 1)) ;;
             esac
             local opp_is_valid=1
             if (( try_x < 0 || try_x >= COLS || try_y < 0 || try_y >= ROWS )); then opp_is_valid=0; fi
             if [[ $opp_is_valid -eq 1 ]]; then
                for ((i=0; i<${#SNAKE_POSITIONS[@]}-1; i++)); do if [[ "${SNAKE_POSITIONS[$i]}" == "$try_y,$try_x" ]]; then opp_is_valid=0; break; fi; done
             fi
             if [[ $opp_is_valid -eq 1 ]]; then
                 curr_dir=$opposite_dir
                 STRAIGHT_COUNT=0
             else
                 # Trapped - will stop in update_algorithm
                 echo "-1" # Signal trapped state
                 return
             fi
        fi
        # Else: No turn needed or possible, continue straight
    else
        ((STRAIGHT_COUNT++))
    fi
    
    echo $curr_dir
}

# Update algorithm - one step
update_algorithm() {
    ((SNAKE_MOVES++))
    
    # Choose next direction
    local new_direction=$(choose_direction)
    
    # Check if trapped
    if [[ $new_direction -eq -1 ]]; then
        STATUS_MESSAGE="Snake trapped! Moves: $SNAKE_MOVES"
        return 1 # Signal trapped
    fi
    
    SNAKE_DIRECTION=$new_direction
    
    # Calculate new head position
    local head="${SNAKE_POSITIONS[0]}"
    local head_y="${head%,*}"
    local head_x="${head#*,}"
    
    local new_y=$head_y
    local new_x=$head_x
    
    case $SNAKE_DIRECTION in
        $DIRECTION_RIGHT) new_x=$((head_x + 1)) ;;
        $DIRECTION_DOWN)  new_y=$((head_y + 1)) ;;
        $DIRECTION_LEFT)  new_x=$((head_x - 1)) ;;
        $DIRECTION_UP)    new_y=$((head_y - 1)) ;;
    esac
    
    # Check bounds - stop if we hit edge
    if (( new_y < 0 || new_y >= ROWS || new_x < 0 || new_x >= COLS )); then
        STATUS_MESSAGE="Snake reached edge! Moves: $SNAKE_MOVES"
        # Update the final position before stopping
        draw_snake
        return 1  # Signal to stop
    fi
    
    # Check for self-collision before moving
    local collision=0
    for ((i=0; i<${#SNAKE_POSITIONS[@]}-1; i++)); do # Don't check tail
        if [[ "${SNAKE_POSITIONS[$i]}" == "$new_y,$new_x" ]]; then
            collision=1
            break
        fi
    done

    if [[ $collision -eq 1 ]]; then
        STATUS_MESSAGE="Snake collided with self! Moves: $SNAKE_MOVES"
        # Update the final position before stopping
        draw_snake
        return 1 # Stop on collision
    fi

    # Clear the current tail position before moving
    local tail="${SNAKE_POSITIONS[${#SNAKE_POSITIONS[@]}-1]}"
    if [[ -n "$tail" ]]; then
        grid[$tail]=""
        collapsed[$tail]=0
    fi
    
    # Add new head position
    SNAKE_POSITIONS=("$new_y,$new_x" "${SNAKE_POSITIONS[@]}")
    
    # Trim to maintain fixed length
    if [[ ${#SNAKE_POSITIONS[@]} -gt $SNAKE_LENGTH ]]; then
        SNAKE_POSITIONS=("${SNAKE_POSITIONS[@]:0:$SNAKE_LENGTH}")
    fi
    
    # Draw the snake in its new position
    draw_snake
    
    STATUS_MESSAGE="Length: $SNAKE_LENGTH | Moves: $SNAKE_MOVES | Straight: $STRAIGHT_COUNT | Dir: $SNAKE_DIRECTION"
    return 0
}
