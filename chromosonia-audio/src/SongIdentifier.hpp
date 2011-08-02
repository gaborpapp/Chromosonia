#include <string>

#define songIdScript "identify_song.py"
#define _songIdScriptLocations {"./", "addons/chromosonia-audio/"}

class SongIdentifier {
public:
  SongIdentifier();
  bool identify(const char *filename);
  std::string getArtist() { return artist; }
  std::string getSong() { return song; }
  float getDanceability();

private:
  void executeCodegen();
  void getSongIdScriptLocation();
  bool fileExists(const char *);
  void processLine(char *);
  const char *songIdScriptLocation;
  std::string artist;
  std::string song;
  float danceability;
};
