#include "EchonestInterface.hpp"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>

#define CODEGEN_TEMP_FILENAME "/tmp/codegen_buffer"

EchonestInterface::EchonestInterface(int _sampleRate, float codegenDuration) {
  sampleRate = _sampleRate;
  codegenNumFrames = (unsigned int) (codegenDuration * sampleRate);
  bufferCount = 0;
  pthread_mutex_init(&mutex, NULL);
  buffering = false;
  getSongIdScriptLocation();
  startCodegenBuffering();
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

void EchonestInterface::executeCodegen() {
  sf_close(codegenBuffer);
  fprintf(stderr, "executing codegen...\n");
  char command[1024];
  sprintf(command, "/bin/sh %s%s %s", songIdScriptLocation, songIdScript, bufferFilename);
  fprintf(stderr, "codegen command: %s\n", command);
  if(system(command) == -1)
    fprintf(stderr, "WARNING: failed to execute command\n");
}

void EchonestInterface::getSongIdScriptLocation() {
  songIdScriptLocation = NULL;
  const char *songIdScriptLocations[] = _songIdScriptLocations;
  char filename[1024];
  int numLocations = sizeof(songIdScriptLocations) / sizeof(char*);
  for(int i = 0; i < numLocations; i++) {
    sprintf(filename, "%s%s", songIdScriptLocations[i], songIdScript);
    if(fileExists(filename)) {
      songIdScriptLocation = songIdScriptLocations[i];
      fprintf(stderr, "located song identification script in %s\n", songIdScriptLocation);
      return;
    }
  }
  if(songIdScriptLocation == NULL) {
    fprintf(stderr, "WARNING: failed to locate song identification script! looked in:\n");
    for(int i = 0; i < numLocations; i++)
      fprintf(stderr, "  %s\n", songIdScriptLocations[i]);
  }
}

bool EchonestInterface::fileExists(const char *filename) {
  struct stat stFileInfo;
  return stat(filename, &stFileInfo) == 0;
}

void EchonestInterface::stopCodegenBuffering() {
  unlink(bufferFilename);
}

void EchonestInterface::processCodegenBufferInNewThread() {
  pthread_create(&processingThread, 0, &EchonestInterface::processCodegenBufferStartThread, this);
}

void EchonestInterface::processCodegenBuffer() {
  pthread_mutex_lock(&mutex);
  executeCodegen();
  stopCodegenBuffering();
  startCodegenBuffering();
  pthread_mutex_unlock(&mutex);
}
