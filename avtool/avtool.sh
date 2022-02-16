channels=${channels:-2}                # 1-mono, 2-stereo
audio_input=${audio_input:-pulse}      # pulse or alsa
samplerate=${samplerate:-48000}        # audio sample rate
acodec=${acodec:-vorbis}               # vorbis, opus, libopus
fmt=${fmt:-mkv}                        #  flv, mkv
framerate=24

#screen=eDP-1                           # avtool-list-screens
#screen_size=3400x1440
#screen_coord=":0.0"

screen=HDMI-1                           # avtool-list-screens
screen_size=3400x1440
screen_coord=":0.0"

avtool-help(){

cat <<EOF

Avtool:

  - records screen and audio
  - records uncompressed audio
  - records opus audio 

channels: $channels  {1,2}
audio_input: $audio_input  {pulse, alsa}
acodec: $acodec  {aac,vorbis,opus,s16le, s24e, f32le, pcm_s8}
samplerate: $samplerate {8000, 16000, 48000}
framerate: $framerate {1 - 60}
fmt=$fmt {flv, mkv}
screen=$screen {avtool-list-screens}

avtool-<tab><tab> to see a list possible commands.
EOF
}

avtool-record-wav() {
  ffmpeg \
         -f alsa \
         -ac $channels \
         -ar $samplerate \
         -i  $audio_input \
         $1$(date +%s).wav 
}

avtool-record-ogg(){
  timestamp=$(date +%s)
  ffmpeg -f alsa \
         -ac $channels  \
         -i  $audio_input \
         -ar $samplerate \
         -acodec $acodec \
         -strict experimental \
         $1$timestamp.ogg
}

avtool-fifo(){
  # atool-fifo fifo.{wav,ogg,mkv,avi}
  ffmpeg \
         -y \
         -f alsa \
         -ac $channels \
         -ar $samplerate \
         -i  $audio_input \
         -acodec $acodec \
         -strict experimental \
         $1 
}

# ffmpeg -framerate 12 -f x11grab -i :0 -f pulse -ac 2 -i default test.flv
avtool-record-video(){
   timestamp=$(date +%s)
   longname="${acodec}_${channels}_10s_${screen_size}_${framerate}"
   filename=${1:-$longname}_$timestamp.$fmt
   ffmpeg -s $screen_size \
         -framerate $framerate \
         -f x11grab \
         -i $screen_coord \
         -f $audio_input \
         -i default \
         -ac $channels \
         -ar $samplerate \
         -acodec $acodec \
         -strict experimental \
         $filename >> avtool.log
}

avtool-play(){
  ffplay $1
}

# eDP-1 connected 1920x1080+709+1440
avtool-set-screen(){
  [ -z $1 ] && screen=eDP-1 || screen=$1  
 
  # example: HDMI-1 connected 3440x1440+0+0
  xrandr_coord=$(avtool-list-screens | \
                 grep connected      | \
                 grep $screen        |  awk '{print $3'})

  read -r  screen_size x y   < <(IFS=+; echo $xrandr_coord)
  echo "avtool-set-screen: screen_size=$screen_size x=$x y=$y"

  DISPLAY="${DISPLAY}"  # :0.0
  screen_coord="${x},${y}"

 echo Using screen: $screen
 echo Using screen_size: $screen_size
 echo Using screen_coord: $screen_coord
}

avtool-list-all(){
  xrandr
  arecord -l
}


avtool-list-screens(){
  avtool-list-all | grep connected
}

avtool-notes() {
cat <<EOF

Uncompressed video:

ffmpeg -f x11grab -s SZ -r 30 -i :0.0 -qscale 0 -vcodec huffyuv grab.avi

via https://unix.stackexchange.com/questions/
73622/how-to-get-near-perfect-screen-recording-quality

EOF
}
