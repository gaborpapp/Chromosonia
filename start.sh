#!/bin/bash
# /usr/local/bin/./jackdmp -R -d coreaudio -r 44100 -p 1024 -o 2 -i 2 -d ~:Aggregate:0
killall jackd
killall fluxus
jackd -d coreaudio -p 1024 &
fluxus -fs -x chromosonia.scm &
sleep 10
jack_connect system:capture_1 system:playback_1
jack_connect system:capture_2 system:playback_2
jack_connect fluxus:in system:capture_1

