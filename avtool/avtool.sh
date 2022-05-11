avtool-record-laptopscreen(){
  ffmpeg -s 1920x1080 \
         -framerate 25 \
         -f x11grab \
         -i :0.0+0,0 \
         -f alsa \
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.flv
}

avtool-record-asus-monitor(){
  ffmpeg -s 1920x1080 \
         -framerate 25 \
         -f x11grab \
         -i :0.0+0,0 \
         -f alsa \
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.flv
}



avtool-record-audio(){
  ffmpeg -f alsa \
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.aac
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
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.flv
}

avtool-help() {
echo "
Check out following to improve capture:
https://unix.stackexchange.com/questions/73622/how-to-get-near-perfect-screen-recording-quality
"
}

avtool-list-inputs(){
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
