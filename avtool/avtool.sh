avtool-record-screen(){
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
