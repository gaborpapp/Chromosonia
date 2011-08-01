#include <sndfile.h>

class EchonestInterface {
public:
  EchonestInterface(int sampleRate, float codegenDuration = 30);
  void feedAudio(const float *, unsigned long numFrames);

private:
  void createCodegenBuffer();
  void appendToCodegenBuffer(const float *, unsigned long numFrames);
  void executeCodegen();
  void deleteCodegenBuffer();

  int sampleRate;
  unsigned int codegenNumFrames;
  unsigned int codegenCurrentNumFrames;
  SNDFILE *codegenBuffer;
  char bufferFilename[1024];
  int bufferCount;
};
