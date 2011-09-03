#!/bin/bash

if [ $# -ne 1 ]; then
	exit 0
fi

while :
do
	filename=`find $1 -name \*mp3 | gshuf -n1`
	mplayer -endpos 25 "$filename"
	sleep 2.5
done


