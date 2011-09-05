#!/bin/bash

if [ $# -ne 1 ]; then
	exit 0
fi

while :
do
	filename=`find $1 -name \*mp3 | gshuf -n1`
	mplayer -endpos 35 "$filename"
	sleep 20
done


