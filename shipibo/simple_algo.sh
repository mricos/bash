#!/usr/bin/env bash

# --- Snake Path Algorithm ---
# A simple algorithm that creates meandering snake-like paths with spaces

# Define pages of information about this algorithm
declare -a PAGES
PAGES=(
    "SNAKE PATH ALGORITHM

Creates a single continuous path
that meanders through the grid
with empty space around it.

The path never crosses itself
and grows like a snake."
    
    "HOW IT WORKS

The algorithm prioritizes cells
next to the 'head' of the snake.

It prefers to continue in the
current direction but can turn.

Spaces are added to create
separation between path segments."
    
    "TECHNICAL DETAILS

Uses modified Wave Function Collapse
with path continuity constraints.

Avoids creating intersections (+)
by removing them from the symbol set.

Applies 50% probability for spaces
around the path."
)

# Export the PAGES array for the engine to use
export PAGES

# Symbol set - no intersection symbol for snake
SYMBOLS=("─" "│" "┌" "┐" "└" "┘" " ")

# Initialize rules for the algorithm
init_rules() {
    # Clear any existing rules
    rules=()
    
    # Basic connection rules
    rules["─_left"]="─ ┘ ┐ "
    rules["─_right"]="─ └ ┌ "
    rules["│_up"]="│ └ ┘ "
    rules["│_down"]="│ ┌ ┐ "
    rules["┌_down"]="│ ┌ ┐ "
    rules["┌_right"]="─ └ ┌ "
    rules["┐_down"]="│ ┌ ┐ "
    rules["┐_left"]="─ ┘ ┐ "
    rules["└_up"]="│ └ ┘ "
    rules["└_right"]="─ └ ┌ "
    rules["┘_up"]="│ └ ┘ "
    rules["┘_left"]="─ ┘ ┐ "
    
    # Add rules for space
    rules[" _left"]=" ─ │ ┌ ┐ └ ┘"
    rules[" _right"]=" ─ │ ┌ ┐ └ ┘"
    rules[" _up"]=" ─ │ ┌ ┐ └ ┘"
    rules[" _down"]=" ─ │ ┌ ┐ └ ┘"
    
    # Allow all symbols to connect to space
    for key in "${!rules[@]}"; do
        if [[ "$key" != " _"* ]]; then
            rules[$key]+=" "  # Add space as valid connection
        fi
    done
    
    return 0
}

# Initialize the grid
init_grid() {
    # Reset grid
    for ((y=0; y<ROWS; y++)); do
        for ((x=0; x<COLS; x++)); do
            local key="$y,$x"
            possibilities[$key]="${SYMBOLS[*]}"
            collapsed[$key]=0
        done
    done
    
    # Start with a seed
    local seed_y=$((ROWS/2))
    local seed_x=$((COLS/2))
    local seed_key="$seed_y,$seed_x"
    
    # Start with horizontal line
    grid[$seed_key]="─"
    collapsed[$seed_key]=1
    
    # Propagate from seed
    propagate_constraints "$seed_y" "$seed_x" "─"
    
    return 0
}

# Helper function to filter options
filter_options() {
    local current="$1"
    local allowed="$2"
    local result=""
    
    for opt in $current; do
        if [[ " $allowed " == *" $opt "* ]]; then
            result+="$opt "
        fi
    done
    
    echo "${result% }"
}

# Propagate constraints from a cell to its neighbors
propagate_constraints() {
    local y=$1 x=$2 symbol=$3
    local changed=0
    
    # Four directions
    local directions=("left" "right" "up" "down")
    for dir in "${directions[@]}"; do
        local ny nx
        case "$dir" in
            left)  ny=$y; nx=$((x-1)) ;;
            right) ny=$y; nx=$((x+1)) ;;
            up)    ny=$((y-1)); nx=$x ;;
            down)  ny=$((y+1)); nx=$x ;;
        esac
        
        # Check bounds
        if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then
            continue
        fi
        
        local nkey="$ny,$nx"
        # Skip if already collapsed
        if [[ "${collapsed[$nkey]}" == "1" ]]; then
            continue
        fi
        
        local rule_key="${symbol}_${dir}"
        local allowed="${rules[$rule_key]}"
        # Skip if no rule exists
        if [[ -z "$allowed" ]]; then
            continue
        fi
        
        local current="${possibilities[$nkey]}"
        local new_options=$(filter_options "$current" "$allowed")
        
        # Update if options changed
        if [[ "$current" != "$new_options" ]]; then
            possibilities[$nkey]="$new_options"
            changed=1
            
            # If no options left, mark as contradiction
            if [[ -z "$new_options" ]]; then
                grid[$nkey]="X"
                collapsed[$nkey]=1
            # If only one option left, collapse it
            elif [[ "$(echo $new_options | wc -w)" -eq 1 ]]; then
                grid[$nkey]="$new_options"
                collapsed[$nkey]=1
                # Recursively propagate from this newly collapsed cell
                propagate_constraints "$ny" "$nx" "$new_options"
            fi
        fi
    done
    
    # If any options changed, propagate to neighbors of neighbors
    if [[ $changed -eq 1 ]]; then
        for dir in "${directions[@]}"; do
            local ny nx
            case "$dir" in
                left)  ny=$y; nx=$((x-1)) ;;
                right) ny=$y; nx=$((x+1)) ;;
                up)    ny=$((y-1)); nx=$x ;;
                down)  ny=$((y+1)); nx=$x ;;
            esac
            
            # Check bounds and whether cell is collapsed
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then
                continue
            fi
            
            local nkey="$ny,$nx"
            if [[ "${collapsed[$nkey]}" == "1" ]]; then
                local nsymbol="${grid[$nkey]}"
                # Only propagate from non-space cells
                if [[ "$nsymbol" != " " ]]; then
                    propagate_constraints "$ny" "$nx" "$nsymbol"
                fi
            fi
        done
    fi
}

# Keep track of the last cell we chose
declare -g LAST_CELL=""

# Find growth points - cells where the snake can continue
find_snake_head() {
    local -a candidates=()
    
    # Look for all growth cells - collect ALL options instead of just returning the first
    for key in "${!collapsed[@]}"; do
        if [[ "${collapsed[$key]}" == "1" && "${grid[$key]}" != " " ]]; then
            local y="${key%,*}"
            local x="${key#*,}"
            
            for dir in "right" "down" "left" "up"; do
                local ny nx
                case "$dir" in
                    left)  ny=$y; nx=$((x-1)) ;;
                    right) ny=$y; nx=$((x+1)) ;;
                    up)    ny=$((y-1)); nx=$x ;;
                    down)  ny=$((y+1)); nx=$x ;;
                esac
                
                # Skip if out of bounds
                if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then
                    continue
                fi
                
                local nkey="$ny,$nx"
                if [[ "${collapsed[$nkey]}" == "0" && "$nkey" != "$LAST_CELL" ]]; then
                    candidates+=("$nkey")
                fi
            done
        fi
    done
    
    # If we have candidates, pick one randomly
    if [[ ${#candidates[@]} -gt 0 ]]; then
        LAST_CELL="${candidates[$((RANDOM % ${#candidates[@]}))]}"
        echo "$LAST_CELL"
        return 0
    fi
    
    return 1  # No growth point found
}

# Update algorithm - one step
update_algorithm() {
    # Find a cell to continue the snake
    local cell_to_collapse
    cell_to_collapse=$(find_snake_head)
    
    # If no valid cell found, stop
    if [[ $? -ne 0 || -z "$cell_to_collapse" ]]; then
        echo "Snake complete! No more cells to collapse."
        return 1  # Signal to stop running
    fi
    
    # Collapse the cell
    local y="${cell_to_collapse%,*}"
    local x="${cell_to_collapse#*,}"
    local -a opts=(${possibilities[$cell_to_collapse]})
    
    # Choose symbol - space or path
    local symbol
    
    # High chance for space to create separation
    if [[ " ${opts[*]} " == *" "* && $(( RANDOM % 100 )) -lt 50 ]]; then
        symbol=" "
    else
        # Find the direction of connection
        local connected=""
        for dir in "left" "right" "up" "down"; do
            local ny nx
            case "$dir" in
                left)  ny=$y; nx=$((x-1)) ;;
                right) ny=$y; nx=$((x+1)) ;;
                up)    ny=$((y-1)); nx=$x ;;
                down)  ny=$((y+1)); nx=$x ;;
            esac
            
            # Skip if out of bounds
            if (( ny < 0 || ny >= ROWS || nx < 0 || nx >= COLS )); then
                continue
            fi
            
            local nkey="$ny,$nx"
            if [[ "${collapsed[$nkey]}" == "1" && "${grid[$nkey]}" != " " ]]; then
                connected+="$dir "
            fi
        done
        
        # Filter non-space options
        local non_space_opts=()
        for opt in "${opts[@]}"; do
            if [[ "$opt" != " " ]]; then
                non_space_opts+=("$opt")
            fi
        done
        
        # Choose appropriate symbol based on connection direction
        if [[ ${#non_space_opts[@]} -gt 0 ]]; then
            # Default to random
            symbol="${non_space_opts[$((RANDOM % ${#non_space_opts[@]}))]}"
            
            # Try to choose a more appropriate symbol based on connection
            if [[ $connected == *"left"* && ! $connected == *"right"* ]]; then
                # Connect from left - prefer horizontal or turn
                local valid_opts=()
                for opt in "${non_space_opts[@]}"; do
                    if [[ "$opt" == "─" || "$opt" == "┐" || "$opt" == "┘" ]]; then
                        valid_opts+=("$opt")
                    fi
                done
                if [[ ${#valid_opts[@]} -gt 0 ]]; then
                    symbol="${valid_opts[$((RANDOM % ${#valid_opts[@]}))]}"
                fi
            elif [[ $connected == *"right"* && ! $connected == *"left"* ]]; then
                # Connect from right - prefer horizontal or turn
                local valid_opts=()
                for opt in "${non_space_opts[@]}"; do
                    if [[ "$opt" == "─" || "$opt" == "┌" || "$opt" == "└" ]]; then
                        valid_opts+=("$opt")
                    fi
                done
                if [[ ${#valid_opts[@]} -gt 0 ]]; then
                    symbol="${valid_opts[$((RANDOM % ${#valid_opts[@]}))]}"
                fi
            elif [[ $connected == *"up"* && ! $connected == *"down"* ]]; then
                # Connect from up - prefer vertical or turn
                local valid_opts=()
                for opt in "${non_space_opts[@]}"; do
                    if [[ "$opt" == "│" || "$opt" == "└" || "$opt" == "┘" ]]; then
                        valid_opts+=("$opt")
                    fi
                done
                if [[ ${#valid_opts[@]} -gt 0 ]]; then
                    symbol="${valid_opts[$((RANDOM % ${#valid_opts[@]}))]}"
                fi
            elif [[ $connected == *"down"* && ! $connected == *"up"* ]]; then
                # Connect from down - prefer vertical or turn
                local valid_opts=()
                for opt in "${non_space_opts[@]}"; do
                    if [[ "$opt" == "│" || "$opt" == "┌" || "$opt" == "┐" ]]; then
                        valid_opts+=("$opt")
                    fi
                done
                if [[ ${#valid_opts[@]} -gt 0 ]]; then
                    symbol="${valid_opts[$((RANDOM % ${#valid_opts[@]}))]}"
                fi
            fi
        else {
            # No non-space options available
            symbol="${opts[$((RANDOM % ${#opts[@]}))]}"
        }
        fi
    fi
    
    # Update grid
    grid[$cell_to_collapse]="$symbol"
    collapsed[$cell_to_collapse]=1
    
    # Propagate constraints
    propagate_constraints "$y" "$x" "$symbol"
    
    # Count snake segments (non-space collapsed cells)
    local snake_length=0
    local total_collapsed=0
    for k in "${!collapsed[@]}"; do
        if [[ "${collapsed[$k]}" == "1" ]]; then
            ((total_collapsed++))
            if [[ "${grid[$k]}" != " " ]]; then
                ((snake_length++))
            fi
        fi
    done
    
    # Set the global STATUS_MESSAGE directly instead of echoing
    STATUS_MESSAGE="Added ${symbol} at ($y,$x) | Snake length: $snake_length | Progress: $total_collapsed/$((ROWS*COLS))"
    return 0 # Signal success
}
