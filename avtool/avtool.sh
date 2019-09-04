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
avtool-record-audio(){
  ffmpeg -f alsa \
         -ac 2 \
         -i pulse \
         -acodec aac \
         -strict experimental \
         $1.aac
}
avtool-record-monitor(){
  ffmpeg -s 1440x900 \
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
