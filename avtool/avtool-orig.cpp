/*
 * Avtool is a collection of shell scripts, C and C++ 
 * programs from recording and playing back multichannel 
 * audio and video.
 *
 * The preferred format is 
 * wav
 * 48k samples / second
 * 24 bit resolution
 * 16 most significant bytes used for audio
 * 8  least significant bytes used for realtime data 
 *
 * For a mono channel, 48k bytes/sec =  384 bits/sec
 * For a stereo channel, 2 x 8 x 48k =  768 bits/sec
 *
 * To compile:
 *
 * git submodule add https://github.com/thestk/stk.git
 * autoconf
 * sudo apt-get install -y libasound2-dev
 * STK_INCLUDE=/home/user/src/stk/include
 * STK_SRC=/home/user/src/stk/src
 * g++ -std=c++11  -O3 -Wall  \
 *     -I$STK_INCLUDE \
 *     -DHAVE_GETTIMEOFDAY \
 *     -D__LINUX_ALSA__ \
 *     -D__LITTLE_ENDIAN__ \
 *     -o avtool \
 *     avtool.cpp \
 *     -L$STK_SRC \
 *     -lstk -lpthread -lasound -lm
 *
 * https://ccrma.stanford.edu/software/stk/fundamentals.html
 *
 */
// rtsine.cpp STK tutorial program
// crtsine.cpp STK tutorial program
#include "SineWave.h"
#include "RtAudio.h"
using namespace stk;
// This tick() function handles sample computation only.  It will be
// called automatically when the system needs a new buffer of audio
// samples.
int tick( void *outputBuffer, void *inputBuffer, unsigned int nBufferFrames,
         double streamTime, RtAudioStreamStatus status, void *dataPointer )
{
  SineWave *sine = (SineWave *) dataPointer;
  register StkFloat *samples = (StkFloat *) outputBuffer;
  for ( unsigned int i=0; i<nBufferFrames; i++ )
    *samples++ = sine->tick();
  return 0;
}
int main()
{
  // Set the global sample rate before creating class instances.
  Stk::setSampleRate( 44100.0 );
  SineWave sine;
  RtAudio dac;
  // Figure out how many bytes in an StkFloat and setup the RtAudio stream.
  RtAudio::StreamParameters parameters;
  parameters.deviceId = dac.getDefaultOutputDevice();
  parameters.nChannels = 1;
  RtAudioFormat format = ( sizeof(StkFloat) == 8 ) ? RTAUDIO_FLOAT64 : RTAUDIO_FLOAT32;
  unsigned int bufferFrames = RT_BUFFER_SIZE;
  try {
    dac.openStream( &parameters, NULL, format, (unsigned int)Stk::sampleRate(), &bufferFrames, &tick, (void *)&sine );
  }
  catch ( RtAudioError &error ) {
    error.printMessage();
    goto cleanup;
  }
  sine.setFrequency(440.0);
  try {
    dac.startStream();
  }
  catch ( RtAudioError &error ) {
    error.printMessage();
    goto cleanup;
  }
  // Block waiting here.
  char keyhit;
  std::cout << "\nPlaying ... press <enter> to quit.\n";
  std::cin.get( keyhit );
  // Shut down the output stream.
  try {
    dac.closeStream();
  }
  catch ( RtAudioError &error ) {
    error.printMessage();
  }
 cleanup:
  return 0;
}
