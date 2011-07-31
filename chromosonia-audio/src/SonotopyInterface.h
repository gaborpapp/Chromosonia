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

#include <sonotopy/sonotopy.hpp>

class SonotopyInterface {
 public:
  SonotopyInterface(int bufferSize, int sampleRate);
  ~SonotopyInterface();
  void feedAudio(const float *, unsigned long numFrames);
  float getVaneAngle();
  float getBeatIntensity();
  int getNumSpectrumBins();
  float getSpectrumBinValue(int bin);
  void setWaveformWindowSize(float secs);
  int getNumWaveformFrames();
  const float *getWaveformBuffer();
  float getGridMapActivation(unsigned int x, unsigned int y);
  const sonotopy::SOM::ActivationPattern* getGridMapActivationPattern();
  unsigned int getGridMapWidth();
  unsigned int getGridMapHeight();
  void setGridMapSize(unsigned int width, unsigned int height);
  void getGridCursor(float &x, float &y);
  void resetAdaptations();

 private:
  sonotopy::BeatTracker *beatTracker;
  sonotopy::SpectrumAnalyzer *spectrumAnalyzer;
  sonotopy::SpectrumBinDivider *spectrumBinDivider;
  sonotopy::CircularBuffer<float> *waveformCircularBuffer;
  float *waveformBuffer;
  int numWaveformFrames;
  sonotopy::CircleMap *circleMap;
  sonotopy::CircleMapParameters circleMapParameters;
  sonotopy::GridMap *gridMap;
  sonotopy::GridMapParameters gridMapParameters;
  unsigned int gridMapWidth, gridMapHeight;
  sonotopy::AudioParameters audioParameters;
  sonotopy::Normalizer normalizer;
};
