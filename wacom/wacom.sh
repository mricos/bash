source $(dirname $BASH_SOURCE)/src/wacom_set.sh

wacom_xrand(){
    xrandr
cat <<EOF
#  xrandr reports W x H at X + Y aka 
#  "normal-left times inverted-right x-pos y-pos"
#  Screen 0: minimum 320 x 200, current 1920 x 2160, maximum 16384 x 16384
#  eDP-1 connected 1920x1080+0+1080 (normal left inverted right x axis y axis)
EOF
}

wacom_calc_ratio(){
    local stylus=$(xsetwacom --list | \
                        grep stylus | \
                            cut -f2 | \
                            cut -d' ' -f2)
    local stylusGeo=($(xsetwacom --get $stylus AREA )) 
      #mon=(0 0 1920 1080) #x,y,w,h # 1.78
      mon=(0 0 3440 1440) #x,y,w,h # 1.78
      echo "Pad Area " ${stylusGeo[@]}
      echo "Pad w:h " $( jq -n ${stylusGeo[2]}/${stylusGeo[3]} )
      echo "Monitor w:h  " $( jq -n ${mon[2]}/${mon[3]} | \
                              jq '.*1000 | round | ./1000')

      echo "Example for 1920x1080"
      echo "1080*1.7 = 1920"
      echo "1080*1.6 = 1728"
      echo "1920-1728 = 192"
      echo "limit screen 192 pixels on right to make ratio 1.6"
      echo "to set entire pad to scren area:"
      echo "wacom_map_to_output 0 0 1782 1080"
      echo "wacom_map_to_output 192 0 1920 1080"
}

wacom_map_to_output(){
  cat <<EOF
  MapToOutput [output]
              Map  the  tablet's  input  area to a given output (e.g. "VGA1").
              Output names may either be the name of a head available  through
              the  XRandR  extension,  or  an  X11 geometry string of the form
              WIDTHxHEIGHT+X+Y. 
EOF
    x=$3; y=$4; w=$1; h=$2;
    echo xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
}

wacom-list(){
  #Wacom Intuos BT M Pen stylus    	id: 11	type: STYLUS    
  #Wacom Intuos BT M Pad pad       	id: 12	type: PAD       
  #Wacom Intuos BT M Pen cursor    	id: 18	type: CURSOR    
  #Wacom Intuos BT M Pen eraser    	id: 17	type: ERASER    
  xsetwacom --list devices
}

wacom_set_env(){
    # regex uses matched group ()
    #  -P   -  perl extenstion for matched group
    #  -o   -  only output matched (not entire line)
    #  \K   -  drop everyting up to match
    #  \d+  -  one or more numbers (the id)
    #  to grab id number
    export WACOM_STYLUS_ID=$(xsetwacom --list \
                            |  grep stylus \
                            | grep -Po '(id: \K\d+)')
    export WACOM_PAD_ID=$(xsetwacom --list \
                            | grep pad \
                            | grep -Po '(id: \K\d+)')
    export WACOM_CURSOR_ID=$(xsetwacom --list \
                            | grep cursor \
                            | grep -Po '(id: \K\d+)' )
    export WACOM_ERASER_ID=$(xsetwacom --list \
                            | grep eraser \
                            | grep -Po '(id: \K\d+)' )
    export WACOM_AREA=($(xsetwacom --get $WACOM_STYLUS_ID Area ))
}

wacom_notes(){
cat <<EOF
mricos@ux305-2:~/mnt/ux305-3$ xsetwacom --list parameters
Important Parameters
---
Area             - Valid tablet area in device coordinates. 
MapToOutput      - Map the device to the given output. 
ResetArea        - Resets the bounding coordinates to default in tablet units. 

Feel
---
PressureCurve    - Bezier curve for pressure
                   Default is 0 0 100 100 [linear] 
Suppress         - Number of points trimmed (default is 2). 
RawSample        - Number of raw data used to filter the points (default is 4). 
CursorProximity  - Sets cursor distance for proximity-out in distance
                   from the tablet (default is 10 for Intuos series,
                   42 for Graphire series). 
Threshold        - Sets tip/eraser pressure threshold (default is 27). 
TapTime          - Minimum time between taps for a right click
                   (default is 250). 

USB info
---
ToolID           - Returns the tool ID of the current tool in proximity.
TabletID         - Returns the tablet ID of the associated device. 
ToolSerial       - Returns the serial number of the current device in proximity.
BindToSerial     - Binds this device to the serial number.
ToolDebugLevel   - Level of debugging trace for individual tools
                   (default is 0 [off]). 
TabletDebugLevel - Level of debugging statements applied to shared 
                   code paths between all tools associated with the
                   same tablet (default is 0 [off]). 

X11
---
Button           - X11 event to which the given button should be mapped. 
RelWheelUp       - X11 event to which relative wheel up should be mapped. 
RelWheelDown     - X11 event to which relative wheel down should be mapped. 
AbsWheelUp       - X11 event to which absolute wheel up should be mapped. 
AbsWheelDown     - X11 event to which absolute wheel down should be mapped. 
AbsWheel2Up      - X11 event to which absolute wheel up should be mapped. 
AbsWheel2Down    - X11 event to which absolute wheel down should be mapped. 
StripLeftUp      - X11 event to which left strip up should be mapped. 
StripLeftDown    - X11 event to which left strip down should be mapped. 
StripRightUp     - X11 event to which right strip up should be mapped. 
StripRightDown   - X11 event to which right strip down should be mapped. 


Misc.
---
all              - Get value for all parameters. 
Mode             - Switches cursor movement mode (default is absolute). 
ToolType         - Returns the tool type of the associated device. 
Touch            - Turns on/off Touch events (default is on). 
Rotate           - Sets the rotation of the tablet. 
                   Values = none, cw, ccw, half (default is none). 
Gesture          - Turns on/off multi-touch gesture events (default is on). 
                   Regular Intuos pad does not support.
ZoomDistance     - Minimum distance for a zoom gesture (default is 50). 
HWTouchSwitchState - Touch events turned on/off by hardware switch. 
PanScrollThreshold - Adjusts distance required for pan actions to
                     generate a scroll event
PressureRecalibration - Turns on/off Tablet pressure recalibration
ToolSerialPrevious - Returns the serial number of the previous device 
                     in proximity.
TabletPCButton   - Turns on/off Tablet PC buttons (default is off 
                   for regular tablets, on for Tablet PC). 
ScrollDistance   - Minimum motion before sending a scroll gesture 
                   (default is 20). 
EOF
}

wacom_set_3415_left(){
    local h=${1:-1440}
    local w=$(( h * 16 / 10 ))  # maintain 16:10 aspect ratio
    local x=0                   # shift to the left (no horizontal offset)
    local y=0                   # no vertical shift
    echo "Using h,w = $h,$w"
    echo xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
}


wacom_set_3415_right(){
    local h=1440
    local w=$(( $h * 16 / 10 ))
    local x=$(( 3440 - $w ))   # shift it to the right
    local y=0                  # dont shift down
    echo "Using h,w = $h,$w"
    
    echo xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
}

wacom_reset_area(){
    echo xsetwacom set $WACOM_STYLUS_ID ResetArea
    xsetwacom set $WACOM_STYLUS_ID ResetArea
    xsetwacom set $WACOM_STYLUS_ID Rotate none
}

wacom_rotate_half(){
    xsetwacom set $WACOM_STYLUS_ID Rotate half
}

wacom_rotate_none(){
    xsetwacom set $WACOM_STYLUS_ID Rotate none
}

wacom_set_3415_stylus_wide(){
    wacom_reset_area
    # Cant resize and rotate. Use inverted coordinates 
    # for Wacom Area instead.
    #xsetwacom set $WACOM_STYLUS_ID Rotate half # left handed
    padW=$(( ${WACOM_AREA[2]} ))
    padH=$(( ${WACOM_AREA[3]} ))
    padH_new=$(( $padW * 10 / 23 )) # divide by 2.3 using integers
    local w=3440
    local h=1440
    local x=0                  # shift it to the right
    local y=$((0))                  # dont shift down
    padH_diff=$(( $padH - $padH_new ))
    echo "Using Monitor h,w = $h,$w"
    echo "Pad padH=$padH,padH_new=$padH_new, padHdiff=$padH_diff, padW=$padW"
    echo xsetwacom set $WACOM_STYLUS_ID Area $padW $padH 0 6072
    xsetwacom set $WACOM_STYLUS_ID Area $padW $padH 0 $padH_diff 
    xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
}
wacom_set_env
