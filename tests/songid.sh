#!/bin/bash
APIKEY=X3SDZXZXQQ6R8C69O # Gabor's API key

all=0
idf=0

for FILE in "$@"
do
	echo "generating echoprint code for $FILE..."
	echoprint-codegen "$FILE" 0 30 >temp.json
	echo "identifying..."
	curl -s -X POST -H "Content-Type:application/octet-stream" "http://developer.echonest.com/api/v4/song/identify?api_key=$APIKEY" --data-binary "@temp.json" -o temp.out
	grep artist_name temp.out >/dev/null
	if [ $? -eq 0 ]
	then
		idf=$(( idf += 1 ))
	fi
	all=$(( all += 1))
	cat temp.out
	rm -f temp.json temp.out
	echo -e "\n"
done
echo "$idf / $all"

