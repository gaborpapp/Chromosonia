#include "SongIdentifier.hpp"
#include <stdlib.h>
#include <sys/stat.h>
#include <stdio.h>

SongIdentifier::SongIdentifier() {
  getSongIdScriptLocation();
}

bool SongIdentifier::identify(const char *filename) {
  fprintf(stderr, "executing codegen...\n");
  char command[1024];
  sprintf(command, "%s%s %s", songIdScriptLocation, songIdScript, filename);
  fprintf(stderr, "codegen command: %s\n", command);
  if(system(command) == -1) {
    fprintf(stderr, "WARNING: failed to execute command\n");
    return false;
  }
  return true;
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
    fprintf(stderr, "WARNING: failed to locate song identification script! looked in:\n");
    for(int i = 0; i < numLocations; i++)
      fprintf(stderr, "  %s\n", songIdScriptLocations[i]);
  }
}

bool SongIdentifier::fileExists(const char *filename) {
  struct stat stFileInfo;
  return stat(filename, &stFileInfo) == 0;
}
