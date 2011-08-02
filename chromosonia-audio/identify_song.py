#!/usr/bin/python

# This script takes an audio file and performs an echoprint lookup on it.
# Requirements: pyechonest >= 4.2.15 http://code.google.com/p/pyechonest/
#               The echoprint-codegen binary (run make install in echoprint-codegen/src)

import sys
import os

import pyechonest.config as config
import pyechonest.song as song

#config.CODEGEN_BINARY_OVERRIDE = os.path.abspath("../echoprint-codegen")
config.CODEGEN_BINARY_OVERRIDE = "/usr/local/bin/echoprint-codegen" # Alex: for some reason, an override is needed even for this default install location
config.ECHO_NEST_API_KEY='S930OYGGEBE2MASJH' # Alex' API key

def lookup(file):
    # Note that song.identify reads just the first 30 seconds of the file
    fp = song.util.codegen(file)
    #print "fp=%s" % fp
    if len(fp) and "code" in fp[0]:
        # The version parameter to song/identify indicates the use of echoprint
        result = song.identify(query_obj=fp, version="4.11")
        print "Got result:", result
        if len(result):
            print "Artist: %s (%s)" % (result[0].artist_name, result[0].artist_id)
            print "Song: %s (%s)" % (result[0].title, result[0].id)
        else:
            print "No match. This track may not be in the database yet."
    else:
        print "Couldn't decode", file
            

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print >>sys.stderr, "Usage: %s <audio file>" % sys.argv[0]
        sys.exit(1)
    lookup(sys.argv[1])
