// Copyright (C) 2011 Alexander Berman
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

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
  processingCodegenBuffer = false;
  shouldRestartBufferingAfterProcessing = true;
  songIdentifier = new SongIdentifier();
}

float EchonestInterface::getDanceability() {
  return songIdentifier->getDanceability();
}

std::string EchonestInterface::getArtist() {
  return songIdentifier->getArtist();
}

std::string EchonestInterface::getSong() {
  return songIdentifier->getSong();
}

void EchonestInterface::restartBufferingAfterProcessing(bool v) {
  shouldRestartBufferingAfterProcessing = v;
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
  processingCodegenBuffer = true;
  pthread_create(&processingThread, 0, &EchonestInterface::processCodegenBufferStartThread, this);
}

void EchonestInterface::processCodegenBuffer() {
  pthread_mutex_lock(&mutex);
  sf_close(codegenBuffer);
  songIdentifier->identify(bufferFilename);
  stopCodegenBuffering();
  processingCodegenBuffer = false;
  if(shouldRestartBufferingAfterProcessing) {
    fprintf(stderr, "restarting codegen buffering\n");
    startCodegenBuffering();
  }
  else
    fprintf(stderr, "not restarting codegen buffering\n");
  pthread_mutex_unlock(&mutex);
}

bool EchonestInterface::isProcessingCodegenBuffer() {
  return processingCodegenBuffer;
}
