# this script tests echonest song identification from a code (fingerprint).
# the problem with testing with e.g. the supplied lookup.py example is that
# metadata from ID3 tags are used, which is unrealistic in our scenario.

# a code can be extracted e.g. by running;
# echoprint-codegen filename 10 30
# (where 10 is offset and 30 duration)

import sys
import json
import pyechonest.config as config
import pyechonest.song as song
config.ECHO_NEST_API_KEY='S930OYGGEBE2MASJH'

def identify(code, version):
    kwargs = {}
    kwargs['code'] = code
    query_obj = {"code":code,
                 "tag":0,
                 "metadata": {"version":4.12} # this seems to be required to get a result - I don't know why
                 }
    data = {'query':json.dumps(query_obj)}
    print "query_obj=%s" % query_obj
    result = song.util.callm("%s/%s" % ('song', 'identify'), kwargs, POST=True, data=data)
    return [song.Song(**song.util.fix(s_dict)) for s_dict in result['response'].get('songs',[])]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print >>sys.stderr, "Usage: %s <code>" % sys.argv[0]
        sys.exit(1)
    code = sys.argv[1]
    result = identify(code, version="4.11")
    print "Got result:", result
    if len(result):
        print "Artist: %s (%s)" % (result[0].artist_name, result[0].artist_id)
        print "Song: %s (%s)" % (result[0].title, result[0].id)
    else:
        print "No match. This track may not be in the database yet."
