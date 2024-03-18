#!/bin/bash

# Ensure initial values are non-zero
LINES=$(tput lines)
COLUMNS=$(tput cols)
[ "$LINES" -eq "0" ] && LINES=24   # Fallback to default values if zero
[ "$COLUMNS" -eq "0" ] && COLUMNS=80

# Parameters for sine waves
f1=0.05   # Frequency for the first wave
a1=$((LINES / 4))  # Amplitude for the first wave, ensure non-zero
p1=0      # Phase for the first wave
n1=0.05   # Noise factor for the first wave

f2=0.07   # Frequency for the second wave
a2=$((LINES / 5))  # Amplitude for the second wave, ensure non-zero
p2=1      # Phase for the second wave
n2=0.05   # Noise factor for the second wave

# Hide cursor for cleaner animation
tput civis
clear

adjust_parameter() {
    case $1 in
        q) f1=$(echo "$f1 - 0.01" | bc);;
        e) f1=$(echo "$f1 + 0.01" | bc);;
        w) a1=$((a1 + 1));;
        s) a1=$((a1 - 1));;
        a) p1=$(echo "$p1 - 0.1" | bc);;
        d) p1=$(echo "$p1 + 0.1" | bc);;
        u) f2=$(echo "$f2 - 0.01" | bc);;
        o) f2=$(echo "$f2 + 0.01" | bc);;
        j) a2=$((a2 + 1));;
        l) a2=$((a2 - 1));;
        i) p2=$(echo "$p2 - 0.1" | bc);;
        k) p2=$(echo "$p2 + 0.1" | bc);;
        p) ((paused ^= 1));;
    esac
}

# Function to draw sine waves
draw_sine() {
    clear
    for ((x=0; x<$COLUMNS; x++)); do

        # Calculate wave positions with added noise.
        # Ensure amplitude is non-zero to avoid division by zero.
        y1=$(awk -v a="$a1" -v f="$f1" -v p="$p1" -v x="$x"\
             -v n="$n1" -v l="$LINES" \
             'BEGIN { print int((a == 0 ? 1 : a) * sin(f*x + p) \
               + l / 2 + (rand() - 0.5) * 2 * a * n)}')

        y2=$(awk -v a="$a2" -v f="$f2" -v p="$p2" -v x="$x" \
                -v n="$n2" -v l="$LINES" \
             'BEGIN {print int((a == 0 ? 1 : a) * sin(f*x + p) \
             + l / 2 + (rand() - 0.5) * 2 * a * n)}')

        # Plot the points for both waves, 
        # checking if y-values are within screen bounds
        if [[ ! -z $y1 ]] && [ $y1 -ge 0 ] && [ $y1 -le $LINES ]; then
            printf "\033[%d;%dH*" $y1 $x
        fi
        if [[ ! -z $y2 ]] && [ $y2 -ge 0 ] && [ $y2 -le $LINES ]; then
            printf "\033[%d;%dH-" $y2 $x
        fi
    done
}

# Trap CTRL+C to exit cleanly, restoring cursor visibility
trap 'tput cnorm; clear; exit' INT

# Main loop with input handling
paused=0  # Script is not paused initially
while true; do
    # Update terminal dimensions to handle resizing

    # Draw sine waves
    (( paused == 0 )) && draw_sine

    # Non-blocking read for key input
    read -s -n 1 -t 0.05 key
    if [[ -n $key ]]; then
        LINES=$(tput lines)
        COLUMNS=$(tput cols)
        adjust_parameter $key
    fi

done
