wacom-set-3415(){
    # screen 1440x3440 =>  width:height=2.35 
    # pad 13500x21600  =>  width:height=1.6
    # pad_x_limit=21600/2.35 = 9192
    xsetwacom set 11 MapToOutput HDMI-1
    xsetwacom set 11  Area 0 0 21600 9192
    xsetwacom set 17  Area 0 0 21600 9192
    xsetwacom set 18  Area 0 0 21600 9192
    #xsetwacom set 12  Area 0 0 21600 9192 #12 = PAD
}

wacom-set-3415-tight(){

      #w=1152 # 1152/720 = 1.6
      w=1760 # 1760/1100 = 1.6
      h=1100
      x=${1:-900} # 2200
      y=50
      xsetwacom set $WACOM_STYLUS_ID MapToOutput "${w}x${h}+$x+$y"
      xsetwacom set $WACOM_STYLUS_ID Rotate none
      xsetwacom set $WACOM_STYLUS_ID  Area 0 0 21600 13500 

      # w = 10800
      # h = 13500
      # r = w/h = .8  (narrow, not wide)
      # h_new = 13500
      # w_new = 1.6*h
      #xsetwacom set 12 Area 10800 0 21600 8640 #w1 h1 w2 h2 

}

wacom-set-3415-tight-portrait(){
    # 1728 = 1080*1.6
    # 23 = 1440*1.6
    w=1125
    h=1800  # w=900x h=1400
    x=1100 # 3440/3
    y=0
    xsetwacom set 11 MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set 12 MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set 17 MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set 18 MapToOutput "${w}x${h}+$x+$y"
    xsetwacom set 12  Area 0 0 21600 13500 
    xsetwacom set 12 Rotate ccw
}


# ASUS monitor same res as ASUS laptop
# 1920 - 1728 =  192
# 
wacom-set-asus-laptop(){
    wacom-map-to-output 192 1080 1728 1080
}
wacom-set-asus-monitor(){
    echo "HAER"
    wacom-map-to-output 192 0 1728 1080
}

wacom-set-3415-laptop(){
  # screen 1080x1920 =>  width:height=1.78
  # pad 13500x21600  =>  width:height=1.6
  # pad_x_limit=21600/2.35 = 9192
  xsetwacom set 11 MapToOutput eDP-1
  xsetwacom set 12 MapToOutput eDP-1
  xsetwacom set 18 MapToOutput eDP-1
  xsetwacom set 12  Area 0 0 21600 12148 
}
