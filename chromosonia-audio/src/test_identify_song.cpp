#include "SongIdentifier.hpp"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  if(argc != 2) {
    printf("Usage: %s filename\n", argv[0]);
    exit(0);
  }
  SongIdentifier identifier;
  if(identifier.identify(argv[1])) {
    printf("Artist: '%s'\n", identifier.getArtist().c_str());
    printf("Song: '%s'\n", identifier.getSong().c_str());
  }
  else
    printf("failed to identify song\n");
}
