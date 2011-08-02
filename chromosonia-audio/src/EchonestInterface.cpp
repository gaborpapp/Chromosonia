#include "EchonestInterface.hpp"
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#define CODEGEN_TEMP_FILENAME "/tmp/codegen_buffer"

EchonestInterface::EchonestInterface(int _sampleRate, float codegenDuration) {
  sampleRate = _sampleRate;
  codegenNumFrames = (unsigned int) (codegenDuration * sampleRate);
  bufferCount = 0;
  pthread_mutex_init(&mutex, NULL);
  buffering = false;
  songIdentifier = new SongIdentifier();
  startCodegenBuffering();
}

float EchonestInterface::getDanceability() {
  return songIdentifier->getDanceability();
}

void EchonestInterface::startCodegenBuffering() {
  codegenCurrentNumFrames = 0;
  sprintf(bufferFilename, "%s%04d.wav", CODEGEN_TEMP_FILENAME, bufferCount++);
  SF_INFO sfinfo;
  sfinfo.channels = 1;
  sfinfo.samplerate = sampleRate;
  sfinfo.frames = 0;
  sfinfo.format = SF_FORMAT_WAV | SF_FORMAT_FLOAT;
  sfinfo.sections = 0;
  sfinfo.seekable = 0;
  codegenBuffer = sf_open(bufferFilename, SFM_WRITE, &sfinfo);
  if(codegenBuffer) {
    buffering = true;
    fprintf(stderr, "started codegen buffering\n");
  }
  else
    fprintf(stderr, "WARNING: failed to open codegen temp file with name '%s'", bufferFilename);
}

void EchonestInterface::feedAudio(const float *buffer, unsigned long numFrames) {
  if(pthread_mutex_trylock(&mutex) != 0) return;
  if(!buffering) return;
  unsigned int numFramesToAppend;
  if(codegenCurrentNumFrames + numFrames >= codegenNumFrames)
    numFramesToAppend = codegenNumFrames - codegenCurrentNumFrames;
  else
    numFramesToAppend = numFrames;
  appendToCodegenBuffer(buffer, numFramesToAppend);
  if(codegenCurrentNumFrames >= codegenNumFrames) {
    buffering = false;
    processCodegenBufferInNewThread();
  }
  pthread_mutex_unlock(&mutex);
}

void EchonestInterface::appendToCodegenBuffer(const float *buffer, unsigned long numFrames) {
  sf_writef_float(codegenBuffer, buffer, numFrames);
  codegenCurrentNumFrames += numFrames;
}

void EchonestInterface::stopCodegenBuffering() {
  unlink(bufferFilename);
}

void EchonestInterface::processCodegenBufferInNewThread() {
  pthread_create(&processingThread, 0, &EchonestInterface::processCodegenBufferStartThread, this);
}

void EchonestInterface::processCodegenBuffer() {
  pthread_mutex_lock(&mutex);
  sf_close(codegenBuffer);
  songIdentifier->identify(bufferFilename);
  stopCodegenBuffering();
  startCodegenBuffering();
  pthread_mutex_unlock(&mutex);
}
