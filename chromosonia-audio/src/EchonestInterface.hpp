#include "SongIdentifier.hpp"
#include <sndfile.h>
#include <pthread.h>

class EchonestInterface {
public:
  EchonestInterface(int sampleRate, float codegenDuration = 20);
  void feedAudio(const float *, unsigned long numFrames);
  float getDanceability();

private:
  void processCodegenBufferInNewThread();
  static void* processCodegenBufferStartThread(void *obj) {
    reinterpret_cast<EchonestInterface *>(obj)->processCodegenBuffer();
    return NULL;
  }
  void processCodegenBuffer();
  void startCodegenBuffering();
  void appendToCodegenBuffer(const float *, unsigned long numFrames);
  void stopCodegenBuffering();

  int sampleRate;
  unsigned int codegenNumFrames;
  unsigned int codegenCurrentNumFrames;
  SNDFILE *codegenBuffer;
  char bufferFilename[1024];
  int bufferCount;
  pthread_t processingThread;
  bool buffering;
  pthread_mutex_t mutex;
  SongIdentifier *songIdentifier;
};
