#define songIdScript "identify_song.py"
#define _songIdScriptLocations {"", "addons/chromosonia-audio/"}

class SongIdentifier {
public:
  SongIdentifier();
  bool identify(const char *filename);
  const char *getArtist();
  const char *getSong();
  float getDanceability();

private:
  void executeCodegen();
  void getSongIdScriptLocation();
  bool fileExists(const char *);
  const char *songIdScriptLocation;
};
