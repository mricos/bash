channels=${channels:-2}                # 1-mono, 2-stereo
audio_input=${audio_input:-pulse}      # pulse or alsa
samplerate=${samplerate:-48000}        # audio sample rate
acodec=${acodec:-vorbis}               # vorbis, opus, libopus
fmt=${fmt:-mkv}                        #  flv, mkv
framerate=12
#vcodec="libvpx-vp9 -crf 30 -b:v 300k" 
vcodec="libx264 -crf 20 -preset medium -tune animation"
params264="-preset default -tune animation"

screen=eDP-1                           # avtool-list-screens
screen_size=1920x1080
#screen_coord="0,0"

#screen=HDMI-1                           # avtool-list-screens
#screen_size=3400x1440
#screen_coord="0,0"

avtool-help(){

cat <<EOF

Avtool:

  - records screen and audio
  - records uncompressed audio
  - records opus audio 

channels: $channels  {1,2}
audio_input: $audio_input  {pulse, alsa}
acodec: $acodec  {aac,vorbis,opus,s16le, s24e, f32le, pcm_s8}
vcodec: $vcodec  {https://trac.ffmpeg.org/wiki}
samplerate: $samplerate {8000, 16000, 24000, 48000}
framerate: $framerate {1 - 60}
fmt: $fmt {flv, mkv}
screen: $screen {avtool-list-screens}
screen_size: $screen_size
screen_coord: $screen_coord

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

avtool-record-asus-monitor(){
  ffmpeg -s 1920x1080 \
         -framerate 10 \
         -f x11grab \
         -i :0.0+0,0 \
         -f alsa \
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.flv
}

#       -f fmt (input/output)
#           Force input or output file format. The format is normally auto
#           detected for input files and guessed from the file extension for
#           output files, so this option is not needed in most cases.

#       -c[:stream_specifier] codec (input/output,per-stream)
#       -codec[:stream_specifier] codec (input/output,per-stream)
#           Select an encoder (when used before an output file) or a decoder
#           (when used before an input file) for one or more streams. codec is
#           the name of a decoder/encoder or a special value "copy" (output
#           only) to indicate that the stream is not to be re-encoded.

avtool-record-asus-monitor-opus(){
  local inputCodec=libopus
  local bitrate=128K
  local width=1080 # should get from xrandr
  local height=720 # should get from xrandr
  local inputFmt=x11grab

  ffmpeg \
  -s ${width}x${height} # {} for clarity \ 
  -f $inputFmt \
  -c:a  -b:a bitrate 
}


avtool-record-audio(){
  timestamp=$(date +%s)
  ffmpeg -f alsa \
         -ac $channels  \
         -i  $audio_input \
         -ar $samplerate \
         -acodec $acodec \
         -strict experimental \
         $1$timestamp.ogg
}

avtool-record-mpow(){
  arecord -c 1 -r 48000 -f S16_LE --device="hw:3,0" 
}

avtool-play-mono(){
  local rate=${1:-48000}
  aplay -c 1 -r 48000 -f S16_LE $1
}
avtool-play-stereo(){
  local rate=${1:-48000}
  aplay -c 2 -r $rate -f S16_LE $1
}

# -f cd (16 bit little endian, 44100, stereo) [-f S16_LE -c2 -r44100]
avtool-record-dat(){
   arecord -f dat $1
}

# -f cd (16 bit little endian, 44100, stereo) [-f S16_LE -c2 -r44100]
avtool-play-dat(){
   aplay -f dat $1
}


avtool-record-monitor(){
  #local monSize="1440x900"
  local monSize="1920x1080"
  ffmpeg -s $monSize \
         -framerate 25 \
         -f x11grab \
         -i :0.0+1920,0 \
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
   longname="${acodec}_${channels}_${screen_size}_${framerate}"
   filename=${1:-$longname}_$timestamp.$fmt
   ffmpeg \
          -s $screen_size \
          -framerate $framerate \
          -f x11grab \
          -i "$DISPLAY+$screen_coord" \
          -f $audio_input \
          -i default \
          -ac $channels \
          -ar $samplerate \
          -acodec $acodec \
          -strict experimental \
          -vcodec $vcodec \
          $filename 
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
                 grep $screen        |  awk '{print $4'})

  read -r  screen_size x y   < <(IFS=+; echo $xrandr_coord)
  echo "avtool-set-screen: screen_size=$screen_size x=$x y=$y"

  #DISPLAY="${DISPLAY}"  # :0.0
  screen_coord="${x},${y}" # full parameter for ffmpeg: :0.0+x,y

 echo Using DISPLAY: $DISPLAY
 echo Using screen: $screen
 echo Using screen_size: $screen_size
 echo Using screen_coord: $screen_coord
}

avtool-list-all(){
  xrandr
  arecord -l
}

avtool-record-wav() {
[ -z $1 ] && input=pulse || input=$1
[ -z $2 ] && output=$(date +%s) || output=$2
  echo   ffmpeg \
         -f alsa \
         -ac 2 \
         -i  $input \
         -acodec wav \
         $output.wav
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
