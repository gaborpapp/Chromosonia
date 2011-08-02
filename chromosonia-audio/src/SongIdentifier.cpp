#include "SongIdentifier.hpp"
#include <stdlib.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>

SongIdentifier::SongIdentifier() {
  getSongIdScriptLocation();
  danceability = 0;
}

bool SongIdentifier::identify(const char *filename) {
  fprintf(stderr, "executing song identification script...\n");
  char command[1024];
  sprintf(command, "%s%s %s", songIdScriptLocation, songIdScript, filename);
  fprintf(stderr, "command: %s\n", command);
  FILE *f = popen(command, "r");
  if(f == NULL) {
    fprintf(stderr, "WARNING: failed to execute command\n");
    return false;
  }
  char line[1024];
  while(fgets(line, sizeof(line), f)) {
    fprintf(stderr, "%s", line);
    processLine(line);
  }
  pclose(f);
  return true;
}

void SongIdentifier::processLine(char *line) {
  char *p = strchr(line, '=');
  char *attr, *value;
  if(p) {
    *p = '\0';
    attr = line;
    value = p + 1;
    p = strchr(value, '\r');
    if(p) *p = '\0';
    p = strchr(value, '\n');
    if(p) *p = '\0';
    if(strcmp(attr, "artist") == 0)
      artist = value;
    else if(strcmp(attr, "song") == 0)
      song = value;
    else if(strcmp(attr, "danceability") == 0)
      danceability = atof(value);
  }
}

void SongIdentifier::getSongIdScriptLocation() {
  songIdScriptLocation = NULL;
  const char *songIdScriptLocations[] = _songIdScriptLocations;
  char filename[1024];
  int numLocations = sizeof(songIdScriptLocations) / sizeof(char*);
  for(int i = 0; i < numLocations; i++) {
    sprintf(filename, "%s%s", songIdScriptLocations[i], songIdScript);
    if(fileExists(filename)) {
      songIdScriptLocation = songIdScriptLocations[i];
      fprintf(stderr, "located song identification script in %s\n", songIdScriptLocation);
      return;
    }
  }
  if(songIdScriptLocation == NULL) {
    fprintf(stderr, "WARNING: failed to locate song identification script '%s'! looked in:\n",
	    songIdScript);
    for(int i = 0; i < numLocations; i++)
      fprintf(stderr, "  %s\n", songIdScriptLocations[i]);
  }
}

bool SongIdentifier::fileExists(const char *filename) {
  struct stat stFileInfo;
  return stat(filename, &stFileInfo) == 0;
}
