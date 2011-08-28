#include "SongIdentifier.hpp"
#include <string>
#include <sndfile.h>
#include <pthread.h>

class EchonestInterface {
public:
  EchonestInterface(int sampleRate, float codegenDuration = 20);
  void startCodegenBuffering();
  void processCodegenBufferInNewThread();
  bool isProcessingCodegenBuffer();
  void restartBufferingAfterProcessing(bool);
  void feedAudio(const float *, unsigned long numFrames);
  float getDanceability();
  std::string getArtist();
  std::string getSong();

private:
  static void* processCodegenBufferStartThread(void *obj) {
    reinterpret_cast<EchonestInterface *>(obj)->processCodegenBuffer();
    return NULL;
  }
  void processCodegenBuffer();
  void appendToCodegenBuffer(const float *, unsigned long numFrames);
  void stopCodegenBuffering();

  int sampleRate;
  unsigned int codegenNumFrames;
  unsigned int codegenCurrentNumFrames;
  SNDFILE *codegenBuffer;
  float processingCodegenBuffer;
  char bufferFilename[1024];
  int bufferCount;
  pthread_t processingThread;
  bool buffering;
  pthread_mutex_t mutex;
  SongIdentifier *songIdentifier;
  float shouldRestartBufferingAfterProcessing;
};
