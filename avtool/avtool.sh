channels=${channels:-1}                # 1-mono, 2-stereo
audio_input=${audio_input:-pulse}      # pulse or alsa
samplerate=${samplerate:-48000}        # audio sample rate
acodec=${acodec:-vorbis}               # vorbis, opus, libopus
screen=eDP-1                           # avtool-list-screens

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

avtool-record-video(){
  echo ffmpeg -s $screen_size \
         -framerate 25 \
         -f x11grab \
         -i :$screen_coord \
         -f alsa \
         -ac 1 \
         -i pulse \
         -acodec $acodec  \
         -strict experimental \
         $1$(date +%s).mkv
}

avtool-play(){
  ffplay $1
}

avtool-set-screen(){
  [ -z $1 ] && screen=eDP-1 || screen=$1  

  export screen_coord=$(avtool-list-screens | \
                 grep connected      | \
                 grep $screen        |  awk '{print $3'})

  export screen_size=$(echo $screen_coord | awk -F+ '{print $1}')

 echo Using screen: $screen
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
