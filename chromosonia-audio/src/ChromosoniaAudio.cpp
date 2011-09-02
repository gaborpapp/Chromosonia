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

#include <escheme.h>
#include <iostream>
#include <iterator> // TEMP
#include <jack/jack.h>
#include "SonotopyInterface.h"
#include "EchonestInterface.hpp"
#include "SchemeHelper.h"
#include <pthread.h>

const static float BEAT_PATTERN_CROSSFADE_MS = 1500;

using namespace std;
using namespace sonotopy;
using namespace SchemeHelper;

jack_client_t *jackClient = NULL;
bool jackActivated = false;
jack_port_t *jackInputPort;
SonotopyInterface *sonotopyInterface = NULL;
EchonestInterface *echonestInterface = NULL;
pthread_mutex_t mutex;
bool insideEvent = false;

SOM *genreMap = NULL;
DisjointGridTopology *genreMapTopology;
unsigned int genreMapWidth, genreMapHeight;
unsigned int numGenres = 0;
vector<SOM::Sample> genreKeys;

void setGenreMapLayout(unsigned int numGenres,
		       unsigned int width,
		       unsigned int height,
		       const vector<DisjointGridTopology::Node> &nodes) {
  if(genreMap) {
    delete genreMap;
    delete genreMapTopology;
  }
  genreMapWidth = width;
  genreMapHeight = height;
  genreMapTopology = new DisjointGridTopology(width, height, nodes);
  genreMap = new SOM(numGenres, genreMapTopology);
  genreMap->setLearningParameter(0.01);
  genreMap->setNeighbourhoodParameter(0.7);
  genreMap->setRandomModelValues(0, numGenres);
  genreKeys.clear();
}

class BeatPattern {
public:
  BeatPattern() {
  }

  void addFrame(float x) {
    frames.push_back(x);
  }

  void removeTrailingSilenceFrames() {
    unsigned int numTrailingFrames =
      sonotopyInterface->getEventStateManager()->getTrailingSilenceMs() / 1000
      * sonotopyInterface->getAudioParameters().sampleRate
      / sonotopyInterface->getAudioParameters().bufferSize;
    int newNumFrames = frames.size() - numTrailingFrames;
    if(newNumFrames < 0)
      newNumFrames = 0;
    frames.resize(newNumFrames);
  }

  void crossFade() {
    unsigned int numFadeFrames =
      BEAT_PATTERN_CROSSFADE_MS / 1000
      * sonotopyInterface->getAudioParameters().sampleRate
      / sonotopyInterface->getAudioParameters().bufferSize;
    if(numFadeFrames > frames.size() / 2)
      numFadeFrames = frames.size() / 2;

    vector<float>::iterator front = frames.begin();
    vector<float>::iterator back = frames.begin() + (frames.size() - numFadeFrames);
    for(unsigned int i = 0; i < numFadeFrames; i++) {
      float frontGain = (float) i / numFadeFrames;
      float backGain = 1.0f - frontGain;
      *front = frontGain * (*front) + backGain * (*back);
      front++;
      back++;
    }
    frames.resize(frames.size() - numFadeFrames);
  }

  vector<float>& getFrames() { return frames; }

private:
  vector<float> frames;
  int numTrailingSilenceFrames;
};

BeatPattern *beatPattern = NULL;
vector<float> beatFrames;

void handleAudioEvents(float *buffer, unsigned long numFrames) {
  if(insideEvent) {
    if(sonotopyInterface->getEventStateManager()->isInsideEvent()) {
      beatPattern->addFrame(sonotopyInterface->getBeatIntensity());
      echonestInterface->feedAudio(buffer, numFrames);
    }
    else {
      echonestInterface->restartBufferingAfterProcessing(false);
      echonestInterface->processCodegenBufferInNewThread();
      beatPattern->removeTrailingSilenceFrames();
      beatPattern->crossFade();
      insideEvent = false;

      //cerr << "beat pattern:\n"; copy(beatPattern->getFrames().begin(), beatPattern->getFrames().end(), ostream_iterator<float>(cerr, "\n")); cerr << endl; // TEMP
	  beatFrames = beatPattern->getFrames();
    }
  }
  else {
    if(sonotopyInterface->getEventStateManager()->isInsideEvent()) {
      insideEvent = true;
      if(beatPattern) delete beatPattern;
      beatPattern = new BeatPattern();
      beatPattern->addFrame(sonotopyInterface->getBeatIntensity());
      echonestInterface->restartBufferingAfterProcessing(true);
      echonestInterface->startCodegenBuffering();
      echonestInterface->feedAudio(buffer, numFrames);
    }
  }
}

int jackProcess(jack_nframes_t num_frames, void *arg) {
  jack_default_audio_sample_t *buffer =
    (jack_default_audio_sample_t *) jack_port_get_buffer(jackInputPort, num_frames);
  pthread_mutex_lock(&mutex);
  if(sonotopyInterface->getEventStateManager()->isInsideEvent())
    sonotopyInterface->feedAudio((float *)buffer, num_frames);
  if(!echonestInterface->isProcessingCodegenBuffer()) {
    sonotopyInterface->updateEventState((float *)buffer, num_frames);
    handleAudioEvents((float *)buffer, num_frames);
  }
  pthread_mutex_unlock(&mutex);
  return 0;
}

void jackShutdown(void *arg) {
  std::cout << "disconnected from jack" << std::endl;
  if(sonotopyInterface != NULL) {
    delete sonotopyInterface;
    sonotopyInterface = NULL;
  }
  if(echonestInterface != NULL) {
    delete echonestInterface;
    echonestInterface = NULL;
  }
}

// StartSectionDoc-en
// fluxus-sonotopy
// This module integrates with Sonotopy, a library for perceptually
// analyzing an acoustic signal in real time, e.g. for visualization
// of music. Sonotopy consists of methods to extract high-level
// features from an acoustic waveform. These numeric feature values
// can be interpreted as e.g. shapes, colors or motion parameters.
// fluxus-sonotopy acts as a layer between Jack, Sonotopy and Fluxus.
// Example:
// (init-audio)
// (require racket/math)
// (define (render)
//  (rotate (vector 90 (* 360 (/ (vane) (* pi 2))) 0))
//  (scale (vector (beat) 0.1 0.1))
//  (translate (vector 0.5 0 0))
//  (draw-cube))
// (every-frame (render))
// EndSectionDoc

// StartFunctionDoc-en
// init-audio jackport-string
// Returns: void
// Description:
// Initializes fluxus-sonotopy by connecting to jack. jackport is an
// optional name specifying a port to connect to; if unspecified, the
// user needs to connect manually.
// Example:
// (init-audio "system:capture_1")
// EndFunctionDoc

Scheme_Object *init_audio(int argc, Scheme_Object **argv) {
  bool connect = false;
  string jackSourcePort;
  DECL_ARGV();
  if(argc == 1) {
    ArgCheck("init-audio", "s", argc, argv);
    jackSourcePort = StringFromScheme(argv[0]);
    connect = true;
  }

  if(jackClient == NULL) {
    jackClient = jack_client_open("fluxus", JackNullOption, NULL);
    if(jackClient == NULL) {
      std::cerr << "Failed to connect to jack" << std::endl;
    }
    else {
      jack_on_shutdown(jackClient, jackShutdown, NULL);
      jack_set_process_callback(jackClient, jackProcess, NULL);
      jackInputPort = jack_port_register(jackClient, "in", JACK_DEFAULT_AUDIO_TYPE, JackPortIsInput, 0);
      if(jackInputPort == NULL) {
        std::cerr << "Failed to create jack input port" << std::endl;
      }
    }
  }

  if(jackClient != NULL && sonotopyInterface == NULL) {
    sonotopyInterface = new SonotopyInterface(jack_get_sample_rate(jackClient),
					      jack_get_buffer_size(jackClient));
    echonestInterface = new EchonestInterface(jack_get_sample_rate(jackClient));
    if(!jackActivated) {
      if(jack_activate(jackClient) == 0) {
	jackActivated = true;
	if(connect) {
	  if(jack_connect(jackClient, jackSourcePort.c_str(), jack_port_name(jackInputPort)) != 0)
	    std::cerr << "Failed to connect to jack port " << jackSourcePort << std::endl;
	}
      }
      else
	std::cerr << "Failed to activate jack client" << std::endl;
    }
  }

  MZ_GC_UNREG();
  return scheme_void;
}


// StartFunctionDoc-en
// vane
// Returns: float
// Description:
// Returns an angular value representing the current "direction" of
// the auditory input. The value is related to a continously updated
// circular sonotopic map of recently encountered audio. The output is
// expected to roughly reflect musical and harmonic dynamics. It can
// be used e.g. to control movement. Range: 0 to 2*pi.
// Example:
// (rotate (vector 90 (* 360 (/ (vane) (* pi 2))) 0))
// (draw-cube)
// EndFunctionDoc

Scheme_Object *vane(int argc, Scheme_Object **argv) {
  float angle = 0.0f;
  if(sonotopyInterface != NULL)
    angle = sonotopyInterface->getVaneAngle();
  return scheme_make_float(angle);
}


// StartFunctionDoc-en
// beat
// Returns: float
// Description:
// Returns a value from 0 to 1 representing the current "beat
// intensity" of the audio input. Rhythmic events such as drum hits
// are expected to yield high values. By contrast, low values are
// yielded by silence and other monotonous sounds.
// Example:
// (scale (vector (beat) 0.1 0.1))
// (draw-cube)
// EndFunctionDoc

Scheme_Object *beat(int argc, Scheme_Object **argv) {
  float beat_intensity = 0.0f;
  if(sonotopyInterface != NULL)
    beat_intensity = sonotopyInterface->getBeatIntensity();
  return scheme_make_float(beat_intensity);
}



// StartFunctionDoc-en
// num-spectrum-bins
// Returns: integer
// Description:
// Returns the number of spectrum bins, whose contents can be retrieved by (spectrum-bin).
// Example:
// (num-spectrum-bins)
// EndFunctionDoc

Scheme_Object *num_spectrum_bins(int argc, Scheme_Object **argv) {
  int num_bins = 0;
  if(sonotopyInterface != NULL)
    num_bins = sonotopyInterface->getNumSpectrumBins();
  return scheme_make_integer_value(num_bins);
}


// StartFunctionDoc-en
// spectrum-bin
// Returns: float
// Description:
// Returns the current total power of frequencies in bin number n,
// where 0 <= n < (num-spectrum-bins). Low n values represent low
// frequency bands.
// Example:
// (spectrum-bin 1)
// EndFunctionDoc

Scheme_Object *spectrum_bin(int argc, Scheme_Object **argv) {
  DECL_ARGV();
  ArgCheck("spectrum-bin", "f", argc, argv);
  float value = 0.0f;
  if(sonotopyInterface != NULL)
    value = sonotopyInterface->getSpectrumBinValue(FloatFromScheme(argv[0]));
  MZ_GC_UNREG();
  return scheme_make_float(value);
}


// StartFunctionDoc-en
// waveform-window-size secs-float
// Returns: void
// Description:
// Sets the size of the waveform window, measured in seconds. See
// (waveform). Higher values yield a larger window and thus a slower
// movement of the waveform.
// Example:
// (waveform-window-size 0.1)
// EndFunctionDoc

Scheme_Object *waveform_window_size(int argc, Scheme_Object **argv) {
  DECL_ARGV();
  ArgCheck("waveform-window-size", "f", argc, argv);
  if(sonotopyInterface != NULL)
    sonotopyInterface->setWaveformWindowSize(FloatFromScheme(argv[0]));
  MZ_GC_UNREG();
  return scheme_void;
}


// StartFunctionDoc-en
// num-waveform-frames
// Returns: integer
// Description:
// Returns the size of the waveform window, measured in audio
// frames. This equals the size of the vector return by (waveform).
// Example:
// (num-waveform-frames)
// EndFunctionDoc

Scheme_Object *num_waveform_frames(int argc, Scheme_Object **argv) {
  int num_frames = 0;
  if(sonotopyInterface != NULL)
    num_frames = sonotopyInterface->getNumWaveformFrames();
  return scheme_make_integer_value(num_frames);
}


// StartFunctionDoc-en
// waveform
// Returns: audio-buffer-vector
// Description:
// Returns the waveform (sample values) of the most recent audio
// input, as a vector of float values. The amount of time represented
// by this window is set with (waveform-window-size).
// Example:
// (waveform-window-size 0.1)
//
// (clear)
// (define p (build-ribbon (num-waveform-frames)))
// (with-primitive p
//    (hint-unlit)
//    (pdata-map! (lambda (w) .01) "w"))
//
// (every-frame
//    (let ([a (waveform)])
//        (with-primitive p
//            (pdata-index-map!
//                (lambda (i p)
//                    (vector (* .005 (- i (/ (pdata-size) 2))) (* 1 (vector-ref a i)) 0))
//                "p"))))
// EndFunctionDoc

Scheme_Object *waveform(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  Scheme_Object *tmp = NULL;
  MZ_GC_DECL_REG(3);
  MZ_GC_VAR_IN_REG(0, argv);
  MZ_GC_VAR_IN_REG(1, result);
  MZ_GC_VAR_IN_REG(2, tmp);
  MZ_GC_REG();

  if(sonotopyInterface != NULL) {
    int num_frames = sonotopyInterface->getNumWaveformFrames();
    result = scheme_make_vector(num_frames, scheme_void);
    const float *p = sonotopyInterface->getWaveformBuffer();
    for (int n = 0; n < num_frames; n++) {
      tmp = scheme_make_float(*p++);
      SCHEME_VEC_ELS(result)[n] = tmp;
    }
  }
  else {
    result = scheme_make_vector(0, scheme_void);
  }

  MZ_GC_UNREG();
  return result;
}


// StartFunctionDoc-en
// grid-size grid-size-vector
// Returns: grid-size-vector
// Description:
// If the size vector is provided, sets the size of the sonotopic grid
// and returns the new dimensions. If called without argument, returns
// the current dimensions of the sonotopic grid.
// Example:
// (grid-size)
// (grid-size (vector (10 10 0))
// EndFunctionDoc

Scheme_Object *grid_size(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, argv);
  MZ_GC_VAR_IN_REG(1, result);
  MZ_GC_REG();
  result = scheme_make_vector(3, scheme_void);

  if(argc == 1) {
    ArgCheck("grid-size", "v", argc, argv);
    vector<float> sizeVector = SchemeHelper::FloatVectorFromScheme(argv[0]);
    if(sizeVector.size() == 2 || sizeVector.size() == 3) {
      if(sonotopyInterface != NULL) {
	pthread_mutex_lock(&mutex);
	sonotopyInterface->setGridMapSize(sizeVector[0], sizeVector[1]);
	pthread_mutex_unlock(&mutex);
      }
    }
  }

  float width = 0, height = 0;
  if(sonotopyInterface != NULL) {
    width = sonotopyInterface->getGridMapWidth();
    height = sonotopyInterface->getGridMapHeight();
  }

  SCHEME_VEC_ELS(result)[0] = scheme_make_integer_value(width);
  SCHEME_VEC_ELS(result)[1] = scheme_make_integer_value(height);
  SCHEME_VEC_ELS(result)[2] = scheme_make_integer_value(0);

  MZ_GC_UNREG();
  return result;
}


// StartFunctionDoc-en
// grid-pattern-node x-int y-int
// Returns: float
// Description:
// Returns the sonotopic grid pattern activation value at node
// (x,y). For more information, see (grid-pattern).
// Example:
// (grid-pattern-node x y)
// EndFunctionDoc

Scheme_Object *grid_pattern_node(int argc, Scheme_Object **argv) {
  DECL_ARGV();
  ArgCheck("grid-pattern-node", "ii", argc, argv);
  float value = 0.0f;
  if(sonotopyInterface != NULL) {
    unsigned int x = IntFromScheme(argv[0]);
    unsigned int y = IntFromScheme(argv[1]);
    value = sonotopyInterface->getGridMapActivation(x, y);
  }
  MZ_GC_UNREG();
  return scheme_make_float(value);
}


// StartFunctionDoc-en
// grid-pattern
// Returns: vector of vector of float
// Description:
// The activation pattern can be conceived of as an image or terrain
// whose movements reflect the musical dynamics of the auditory
// input. The pattern is related to a continously updated rectanglar
// sonotopic map of recently encountered auditory input. The function
// returns the activation pattern as a two-dimensional matrix
// represented as a vector of vector of floats in the range 0-1.
// Example:
// see examples/grid-pattern.scm
// EndFunctionDoc

Scheme_Object *grid_pattern(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  Scheme_Object *tmprow = NULL;
  Scheme_Object *tmpnode = NULL;
  MZ_GC_DECL_REG(3);
  MZ_GC_VAR_IN_REG(0, result);
  MZ_GC_VAR_IN_REG(1, tmprow);
  MZ_GC_VAR_IN_REG(2, tmpnode);
  MZ_GC_REG();

  if(sonotopyInterface != NULL) {
    unsigned int gridMapWidth = sonotopyInterface->getGridMapWidth();
    unsigned int gridMapHeight = sonotopyInterface->getGridMapHeight();

    result = scheme_make_vector(gridMapHeight, scheme_void);

    pthread_mutex_lock(&mutex);
    const SOM::ActivationPattern *activationPattern =
      sonotopyInterface->getGridMapActivationPattern();
    SOM::ActivationPattern::const_iterator activationPatternIterator =
      activationPattern->begin();
    for(unsigned int y = 0; y < gridMapHeight; y++) {
      tmprow = scheme_make_vector(gridMapWidth, scheme_void);
      for(unsigned int x = 0; x < gridMapWidth; x++) {
	tmpnode = scheme_make_float(*activationPatternIterator++);
	SCHEME_VEC_ELS(tmprow)[x] = tmpnode;
      }
      SCHEME_VEC_ELS(result)[y] = tmprow;
    }
    pthread_mutex_unlock(&mutex);
  }

  MZ_GC_UNREG();
  return result;
}


// StartFunctionDoc-en
// disjoint-grid-layout grid-size-vector nodes-vector
// Returns: grid-size-vector
// Description:
// Sets the size and nodal layout of the sonotopic disjoint grid. The first vector specifies the width and height. The second vector contains the x and y value for each node in the topology.
// Example:
// (disjoint-grid-size (vector (10 10 0)) #(#(1 1) #(1 2) #(1 3) #(2 1)))
// EndFunctionDoc

Scheme_Object *disjoint_grid_layout(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, argv);
  MZ_GC_VAR_IN_REG(1, result);
  MZ_GC_REG();
  result = scheme_make_vector(3, scheme_void);

  if(argc == 2) {
    //ArgCheck("disjoint-grid-layout", "vv", argc, argv); // doesn't handle arg 2
    vector<float> sizeVector = SchemeHelper::FloatVectorFromScheme(argv[0]);
    if(sizeVector.size() == 2 || sizeVector.size() == 3) {
      Scheme_Object *schemeNodes = argv[1];
      vector<DisjointGridTopology::Node> nodes;
      for (int n=0; n<SCHEME_VEC_SIZE(schemeNodes); n++) {
	Scheme_Object *nodeV = SCHEME_VEC_ELS(schemeNodes)[n];
	int s = SCHEME_VEC_SIZE(nodeV);
	if(s == 2) {
	  if(SCHEME_EXACT_INTEGERP(SCHEME_VEC_ELS(nodeV)[0]) &&
	     SCHEME_EXACT_INTEGERP(SCHEME_VEC_ELS(nodeV)[1])) {
	    int x = IntFromScheme(SCHEME_VEC_ELS(nodeV)[0]);
	    int y = IntFromScheme(SCHEME_VEC_ELS(nodeV)[1]);
	    nodes.push_back(DisjointGridTopology::Node(x, y));
	  }
	}
      }
      if(sonotopyInterface != NULL) {
	pthread_mutex_lock(&mutex);
	sonotopyInterface->setDisjointGridMapLayout(sizeVector[0],
						    sizeVector[1],
						    nodes);
	pthread_mutex_unlock(&mutex);
      }
    }
  }

  float width = 0, height = 0;
  if(sonotopyInterface != NULL) {
    width = sonotopyInterface->getDisjointGridMapWidth();
    height = sonotopyInterface->getDisjointGridMapHeight();
  }

  SCHEME_VEC_ELS(result)[0] = scheme_make_integer_value(width);
  SCHEME_VEC_ELS(result)[1] = scheme_make_integer_value(height);
  SCHEME_VEC_ELS(result)[2] = scheme_make_integer_value(0);

  MZ_GC_UNREG();
  return result;
}

Scheme_Object *genre_map_layout(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, argv);
  MZ_GC_VAR_IN_REG(1, result);
  MZ_GC_REG();
  result = scheme_make_vector(3, scheme_void);

  if(argc == 3) {
    //ArgCheck("genre-map-layout", "ivv", argc, argv); // doesn't handle arg 3
    numGenres = SchemeHelper::IntFromScheme(argv[0]);
    vector<float> sizeVector = SchemeHelper::FloatVectorFromScheme(argv[1]);
    if(sizeVector.size() == 2 || sizeVector.size() == 3) {
      Scheme_Object *schemeNodes = argv[2];
      vector<DisjointGridTopology::Node> nodes;
      for (int n=0; n<SCHEME_VEC_SIZE(schemeNodes); n++) {
	Scheme_Object *nodeV = SCHEME_VEC_ELS(schemeNodes)[n];
	int s = SCHEME_VEC_SIZE(nodeV);
	if(s == 2) {
	  if(SCHEME_EXACT_INTEGERP(SCHEME_VEC_ELS(nodeV)[0]) &&
	     SCHEME_EXACT_INTEGERP(SCHEME_VEC_ELS(nodeV)[1])) {
	    int x = IntFromScheme(SCHEME_VEC_ELS(nodeV)[0]);
	    int y = IntFromScheme(SCHEME_VEC_ELS(nodeV)[1]);
	    nodes.push_back(DisjointGridTopology::Node(x, y));
	  }
	}
      }
      if(sonotopyInterface != NULL) {
	pthread_mutex_lock(&mutex);
	setGenreMapLayout(numGenres,
			  sizeVector[0],
			  sizeVector[1],
			  nodes);
	pthread_mutex_unlock(&mutex);
      }
    }
  }

  float width = 0, height = 0;
  if(sonotopyInterface != NULL) {
    width = genreMapWidth;
    height = genreMapHeight;
  }

  SCHEME_VEC_ELS(result)[0] = scheme_make_integer_value(width);
  SCHEME_VEC_ELS(result)[1] = scheme_make_integer_value(height);
  SCHEME_VEC_ELS(result)[2] = scheme_make_integer_value(0);

  MZ_GC_UNREG();
  return result;
}

Scheme_Object *add_to_genre_map(int argc, Scheme_Object **argv) {
  vector<float> key = SchemeHelper::FloatVectorFromScheme(argv[0]);
  if(genreMap) {
    if(key.size() == numGenres)
      genreKeys.push_back(key);
    else
      cerr << "illegal genre key size: expected " << numGenres << " but got " << key.size() << endl;
  }
  else
    cerr << "tried to add genre key but genre map not initialized" << endl;
  return scheme_void;
}

Scheme_Object *update_genre_map_globally(int argc, Scheme_Object **argv) {
  if(genreMap) {
    for(vector<SOM::Sample>::const_iterator i = genreKeys.begin(); i != genreKeys.end(); i++)
      genreMap->train(*i);
  }
  else
    cerr << "tried to update genre map but genre map not initialized" << endl;
  return scheme_void;
}

Scheme_Object *update_genre_map_partially(int argc, Scheme_Object **argv) {
  int numIterations = SchemeHelper::IntFromScheme(argv[0]);
  static unsigned int keyNum = 0;
  if(genreMap) {
    for(int i = 0; i < numIterations; i++) {
      if(keyNum >= genreKeys.size())
	keyNum = 0;
      genreMap->train(genreKeys[keyNum]);
      keyNum++;
    }
  }
  else
    cerr << "tried to update genre map but genre map not initialized" << endl;
  return scheme_void;
}

Scheme_Object *train_genre_map_with_key(int argc, Scheme_Object **argv) {
  vector<float> key = SchemeHelper::FloatVectorFromScheme(argv[0]);
  if(genreMap) {
    if(key.size() == numGenres)
      genreMap->train(key);
    else
      cerr << "illegal genre key size: expected " << numGenres << " but got " << key.size() << endl;
  }
  else
    cerr << "tried to add genre key but genre map not initialized" << endl;
  return scheme_void;
}

Scheme_Object *genre_map_lookup(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  MZ_GC_DECL_REG(3);
  MZ_GC_VAR_IN_REG(0, result);
  MZ_GC_VAR_IN_REG(1, argv);
  MZ_GC_REG();

  int x=-1, y=-1;
  vector<float> key = SchemeHelper::FloatVectorFromScheme(argv[0]);
  if(genreMap) {
    if(key.size() == numGenres) {
      unsigned int nodeId = genreMap->getWinner(key);
      unsigned int ux, uy;
      genreMapTopology->idToGridCoordinates(nodeId, ux, uy);
      x = ux;
      y = uy;
    }
    else
      cerr << "illegal genre key size: expected " << numGenres << " but got " << key.size() << endl;
  }
  else
    cerr << "tried to lookup from genre map but genre map not initialized" << endl;

  result = scheme_make_vector(2, scheme_void);
  SCHEME_VEC_ELS(result)[0] = scheme_make_integer_value(x);
  SCHEME_VEC_ELS(result)[1] = scheme_make_integer_value(y);

  MZ_GC_UNREG();
  return result;
}

Scheme_Object *print_genre_map(int argc, Scheme_Object **argv) {
  if(genreMap)
    genreMap->writeModelData(cerr);
  return scheme_void;
}

Scheme_Object *print_genre_map_keys(int argc, Scheme_Object **argv) {
  cerr << genreKeys.size() << " key(s):" << endl;
  int n = 1;
  for(vector<SOM::Sample>::const_iterator i = genreKeys.begin(); i != genreKeys.end(); i++) {
    cerr << "key " << n << ":" << endl;
    copy(i->begin(), i->end(), ostream_iterator<float> (cerr, " "));
    cerr << endl;
    n++;
  }
  return scheme_void;
}

// StartFunctionDoc-en
// disjoint-grid-pattern
// Returns: vector of vector of float
// Description:
// Similar to grid-pattern but for the disjoint grid. Non-nodal map content has zero activation.
// EndFunctionDoc

Scheme_Object *disjoint_grid_pattern(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  Scheme_Object *tmprow = NULL;
  Scheme_Object *tmpnode = NULL;
  MZ_GC_DECL_REG(3);
  MZ_GC_VAR_IN_REG(0, result);
  MZ_GC_VAR_IN_REG(1, tmprow);
  MZ_GC_VAR_IN_REG(2, tmpnode);
  MZ_GC_REG();

  if(sonotopyInterface != NULL) {
    unsigned int gridMapWidth = sonotopyInterface->getDisjointGridMapWidth();
    unsigned int gridMapHeight = sonotopyInterface->getDisjointGridMapHeight();

    result = scheme_make_vector(gridMapHeight, scheme_void);

    pthread_mutex_lock(&mutex);
    const SOM::ActivationPattern *activationPattern =
      sonotopyInterface->getDisjointGridMapActivationPattern();
    SOM::ActivationPattern::const_iterator activationPatternIterator =
      activationPattern->begin();
    for(unsigned int y = 0; y < gridMapHeight; y++) {
      tmprow = scheme_make_vector(gridMapWidth, scheme_void);
      for(unsigned int x = 0; x < gridMapWidth; x++) {
	tmpnode = scheme_make_float(*activationPatternIterator++);
	SCHEME_VEC_ELS(tmprow)[x] = tmpnode;
      }
      SCHEME_VEC_ELS(result)[y] = tmprow;
    }
    pthread_mutex_unlock(&mutex);
  }

  MZ_GC_UNREG();
  return result;
}


// StartFunctionDoc-en
// path-cursor
// Returns: vector
// Description:
// Returns a vector representing a position in a 2-d surface. The
// sequence of return values can be expected to constitute a path
// along the surface. The path relates to the activation pattern of a
// sonotopic grid; see also (grid-pattern). Coordinate range:
// (0,0)-(1,1). The returned vector has the form #(x-coordinate
// y-coordinate 0).
// Example:
// see examples/path.scm
// EndFunctionDoc

Scheme_Object *path_cursor(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  Scheme_Object *tmpnode = NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, result);
  MZ_GC_VAR_IN_REG(1, tmpnode);
  MZ_GC_REG();
  result = scheme_make_vector(3, scheme_void);

  float x = 0, y = 0;
  if(sonotopyInterface != NULL)
    sonotopyInterface->getGridCursor(x, y);

  tmpnode = scheme_make_float(x);
  SCHEME_VEC_ELS(result)[0] = tmpnode;
  tmpnode = scheme_make_float(y);
  SCHEME_VEC_ELS(result)[1] = tmpnode;
  tmpnode = scheme_make_float(0);
  SCHEME_VEC_ELS(result)[2] = tmpnode;

  MZ_GC_UNREG();
  return result;
}



// StartFunctionDoc-en
// reset-sonotopy
// Returns: void
// Description:
// Resets adaptations to previously encountered audio, and restarts
// "from scratch." Can speed up re-adaptation when switching from one
// music track to another, especially for tracks of different
// style/genre.
// EndFunctionDoc

Scheme_Object *reset_sonotopy(int argc, Scheme_Object **argv) {
  if(sonotopyInterface != NULL)
    sonotopyInterface->resetAdaptations();
  return scheme_void;
}




Scheme_Object *danceability(int argc, Scheme_Object **argv) {
  float danceability = 0.0f;
  if(echonestInterface != NULL)
    danceability = echonestInterface->getDanceability();
  return scheme_make_float(danceability);
}

Scheme_Object *artist(int argc, Scheme_Object **argv) {
  string artist = "";
  DECL_ARGV();
  if(echonestInterface != NULL)
    artist = echonestInterface->getArtist();
  MZ_GC_UNREG();
  if (artist != "")
	  return scheme_make_utf8_string(artist.c_str());
  else
	  return scheme_false;
}

Scheme_Object *song(int argc, Scheme_Object **argv) {
  string song = "";
  DECL_ARGV();
  if(echonestInterface != NULL)
    song = echonestInterface->getSong();
  MZ_GC_UNREG();
  if (song != "")
	  return scheme_make_utf8_string(song.c_str());
  else
	  return scheme_false;
}

Scheme_Object *inside_event(int argc, Scheme_Object **argv) {
  bool insideEvent = false;
  if(sonotopyInterface != NULL)
    insideEvent = sonotopyInterface->isInsideEvent();
  return scheme_make_integer_value(insideEvent);
}

Scheme_Object *decibel(int argc, Scheme_Object **argv) {
  float db = 0.0f;
  if(sonotopyInterface != NULL)
    db = sonotopyInterface->getEventStateManager()->getCurrentDb();
  return scheme_make_float(db);
}

Scheme_Object *decibel_threshold(int argc, Scheme_Object **argv) {
  DECL_ARGV();

  if(argc == 1) {
    ArgCheck("decibel-threshold", "f", argc, argv);
    if(sonotopyInterface != NULL)
      sonotopyInterface->getEventStateManager()->setDbThreshold(FloatFromScheme(argv[0]));
  }

  float threshold = 0.0f;
  if(sonotopyInterface != NULL)
    threshold = sonotopyInterface->getEventStateManager()->getDbThreshold();

  MZ_GC_UNREG();
  return scheme_make_float(threshold);
}

Scheme_Object *trailing_silence(int argc, Scheme_Object **argv) {
  DECL_ARGV();

  if(argc == 1) {
    ArgCheck("trailing-silence", "f", argc, argv);
    if(sonotopyInterface != NULL)
      sonotopyInterface->getEventStateManager()->setTrailingSilenceMs(FloatFromScheme(argv[0]));
  }

  float trailingSilence = 0.0f;
  if(sonotopyInterface != NULL)
    trailingSilence = sonotopyInterface->getEventStateManager()->getTrailingSilenceMs();

  MZ_GC_UNREG();
  return scheme_make_float(trailingSilence);
}

Scheme_Object *beat_pattern(int argc, Scheme_Object **argv) {
  Scheme_Object *result = NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, argv);
  MZ_GC_VAR_IN_REG(1, result);
  MZ_GC_REG();

  pthread_mutex_lock(&mutex);
  if((sonotopyInterface != NULL) && (beatFrames.size() > 0))
  {
    result = FloatsToScheme(&beatFrames[0], beatFrames.size());
  }
  else {
    result = scheme_make_vector(0, scheme_void);
  }
  pthread_mutex_unlock(&mutex);

  MZ_GC_UNREG();
  return result;
}

Scheme_Object *beat_pattern_framerate(int argc, Scheme_Object **argv) {
  DECL_ARGV();

  float framerate = 0.0f;
  if(sonotopyInterface != NULL)
  {
      framerate = sonotopyInterface->getAudioParameters().sampleRate /
				  sonotopyInterface->getAudioParameters().bufferSize;
  }

  MZ_GC_UNREG();
  return scheme_make_float(framerate);
}

/////////////////////

#ifdef STATIC_LINK
Scheme_Object *sonotopy_scheme_reload(Scheme_Env *env)
#else
Scheme_Object *scheme_reload(Scheme_Env *env)
#endif
{
  Scheme_Env *menv=NULL;
  MZ_GC_DECL_REG(2);
  MZ_GC_VAR_IN_REG(0, env);
  MZ_GC_VAR_IN_REG(1, menv);
  MZ_GC_REG();

  pthread_mutex_init(&mutex, NULL);
  menv=scheme_primitive_module(scheme_intern_symbol("chromosonia-audio"), env);

  scheme_add_global("init-audio",
		    scheme_make_prim_w_arity(init_audio, "init-audio", 0, 1), menv);
  scheme_add_global("vane",
		    scheme_make_prim_w_arity(vane, "vane", 0, 0), menv);
  scheme_add_global("beat",
		    scheme_make_prim_w_arity(beat, "beat", 0, 0), menv);
  scheme_add_global("num-spectrum-bins",
		    scheme_make_prim_w_arity(num_spectrum_bins, "num-spectrum-bins", 0, 0), menv);
  scheme_add_global("spectrum-bin",
		    scheme_make_prim_w_arity(spectrum_bin, "spectrum-bin", 1, 1), menv);
  scheme_add_global("waveform-window-size",
		    scheme_make_prim_w_arity(waveform_window_size, "waveform-window-size", 1, 1), menv);
  scheme_add_global("num-waveform-frames",
		    scheme_make_prim_w_arity(num_waveform_frames, "num-waveform-frames", 0, 0), menv);
  scheme_add_global("waveform",
		    scheme_make_prim_w_arity(waveform, "waveform", 0, 0), menv);
  scheme_add_global("grid-size",
		    scheme_make_prim_w_arity(grid_size, "grid-size", 0, 1), menv);
  scheme_add_global("grid-pattern",
		    scheme_make_prim_w_arity(grid_pattern, "grid-pattern", 0, 0), menv);
  scheme_add_global("grid-pattern-node",
		    scheme_make_prim_w_arity(grid_pattern_node, "grid-pattern-node", 2, 2), menv);
  scheme_add_global("disjoint-grid-layout",
		    scheme_make_prim_w_arity(disjoint_grid_layout, "disjoint-grid-layout", 2, 2), menv);
  scheme_add_global("disjoint-grid-pattern",
		    scheme_make_prim_w_arity(disjoint_grid_pattern, "disjoint-grid-pattern", 0, 0), menv);
  scheme_add_global("path-cursor",
		    scheme_make_prim_w_arity(path_cursor, "path-cursor", 0, 0), menv);
  scheme_add_global("reset-sonotopy",
		    scheme_make_prim_w_arity(reset_sonotopy, "reset-sonotopy", 0, 0), menv);
  scheme_add_global("danceability",
		    scheme_make_prim_w_arity(danceability, "danceability", 0, 0), menv);
  scheme_add_global("artist",
		    scheme_make_prim_w_arity(artist, "artist", 0, 0), menv);
  scheme_add_global("song",
		    scheme_make_prim_w_arity(song, "song", 0, 0), menv);
  scheme_add_global("inside-event",
		    scheme_make_prim_w_arity(inside_event, "inside-event", 0, 0), menv);
  scheme_add_global("decibel",
		    scheme_make_prim_w_arity(decibel, "decibel", 0, 0), menv);
  scheme_add_global("decibel-threshold",
		    scheme_make_prim_w_arity(decibel_threshold, "decibel-threshold", 0, 1), menv);
  scheme_add_global("trailing-silence",
		    scheme_make_prim_w_arity(trailing_silence, "trailing-silence", 0, 1), menv);
  scheme_add_global("genre-map-layout",
		    scheme_make_prim_w_arity(genre_map_layout, "genre-map-layout", 3, 3), menv);
  scheme_add_global("add-to-genre-map",
		    scheme_make_prim_w_arity(add_to_genre_map, "add-to-genre-map", 1, 1), menv);
  scheme_add_global("genre-map-lookup",
		    scheme_make_prim_w_arity(genre_map_lookup, "genre-map-lookup", 1, 1), menv);
  scheme_add_global("update-genre-map-globally",
		    scheme_make_prim_w_arity(update_genre_map_globally, "update-genre-map-globally", 0, 0), menv);
  scheme_add_global("update-genre-map-partially",
		    scheme_make_prim_w_arity(update_genre_map_partially, "update-genre-map-partially", 1, 1), menv);
  scheme_add_global("train-genre-map-with-key",
		    scheme_make_prim_w_arity(train_genre_map_with_key, "train-genre-map-with-key", 1, 1), menv);
  scheme_add_global("print-genre-map",
		    scheme_make_prim_w_arity(print_genre_map, "print-genre-map", 0, 0), menv);
  scheme_add_global("print-genre-map-keys",
		    scheme_make_prim_w_arity(print_genre_map_keys, "print-genre-map-keys", 0, 0), menv);
  scheme_add_global("beat-pattern",
		    scheme_make_prim_w_arity(beat_pattern, "beat-pattern", 0, 0), menv);
  scheme_add_global("beat-pattern-framerate",
		    scheme_make_prim_w_arity(beat_pattern_framerate, "beat-pattern-framerate", 0, 0), menv);

  scheme_finish_primitive_module(menv);
  MZ_GC_UNREG();

  return scheme_void;
}

#ifndef STATIC_LINK
Scheme_Object *scheme_initialize(Scheme_Env *env)
{
  return scheme_reload(env);
}

Scheme_Object *scheme_module_name()
{
  return scheme_intern_symbol("chromosonia-audio");
}
#endif
