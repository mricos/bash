STK_INCLUDE=./stk/include
STK_SRC=./stk/src
g++ -std=c++11  -O3 -Wall  \
   -I$STK_INCLUDE \
   -DHAVE_GETTIMEOFDAY \
   -D__LINUX_ALSA__ \
   -D__LITTLE_ENDIAN__ \
   -o avtool \
   avtool.cpp \
   -L$STK_SRC \
   -lstk -lpthread -lasound -lm
