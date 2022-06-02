STK_INCLUDE=./stk/include
STK_SRC=./stk/src
avtool-build(){
g++ -std=c++11  -O3 -Wall  \
   -I$STK_INCLUDE \
   -DHAVE_GETTIMEOFDAY \
   -D__LINUX_ALSA__ \
   -D__LITTLE_ENDIAN__ \
   -o avtool \
   avtool.cpp \
   -L$STK_SRC \
   -lstk -lpthread -lasound -lm
}

avtool-compile-help(){
cat <<EOF
cut-n-paste to get the goods
wget http://ccrma.stanford.edu/software/stk/release/stk-4.6.2.tar.gz
tar xfvz stk-4.6.2.tar.gz
EOF
}
