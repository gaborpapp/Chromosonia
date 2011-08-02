#include <sndfile.h>
#include <pthread.h>

#define songIdScript "identify_song.py"
#define _songIdScriptLocations {"", "addons/chromosonia-audio/"}

class EchonestInterface {
public:
  EchonestInterface(int sampleRate, float codegenDuration = 30);
  void feedAudio(const float *, unsigned long numFrames);

private:
  void processCodegenBufferInNewThread();
  static void* processCodegenBufferStartThread(void *obj) {
    reinterpret_cast<EchonestInterface *>(obj)->processCodegenBuffer();
    return NULL;
  }
  void processCodegenBuffer();
  void startCodegenBuffering();
  void appendToCodegenBuffer(const float *, unsigned long numFrames);
  void executeCodegen();
  void stopCodegenBuffering();
  void getSongIdScriptLocation();
  bool fileExists(const char *);

  int sampleRate;
  unsigned int codegenNumFrames;
  unsigned int codegenCurrentNumFrames;
  SNDFILE *codegenBuffer;
  char bufferFilename[1024];
  int bufferCount;
  pthread_t processingThread;
  bool buffering;
  pthread_mutex_t mutex;
  const char *songIdScriptLocation;
};
