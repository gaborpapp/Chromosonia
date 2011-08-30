#include <string>

#define songIdScript "identify_song.py"
#ifdef RESOURCES_LOCATION
#define _songIdScriptLocations {".", RESOURCES_LOCATION}
#else
#define _songIdScriptLocations {"."}
#endif

class SongIdentifier {
public:
  SongIdentifier();
  void reset();
  bool identify(const char *filename);
  std::string getArtist() { return artist; }
  std::string getSong() { return song; }
  float getDanceability() { return danceability; }

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
