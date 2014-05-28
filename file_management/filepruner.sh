#!/bin/bash
# filepruner.sh 20140206 JG
# find and delete duplicate files in the current directory based on the md5sum

BEFORESIZE=$(du -sh | awk '{ print $1 }')

find . -maxdepth 1 -mindepth 1 -type f -exec md5sum {} \; | sort > /tmp/filepruner_md5sums.out
[[ -z $(cat /tmp/filepruner_md5sums.out) ]] && exit 99
uniq -w 33 /tmp/filepruner_md5sums.out > /tmp/filepruner_keepers.out
while read j ; do
	GREPFOR=$(echo "$j" | awk '{ print $1 }')
	echo "Processing '$GREPFOR'"
	TMPIFS=$IFS
	IFS=$'\n'
	removelist=( $(grep "$GREPFOR" /tmp/filepruner_md5sums.out | grep -v "$j" | cut -c 35-) )
	for k in "${removelist[@]}" ; do
		echo "Removing $k"
		rm "$k"
	done
	IFS=$TMPIFS
done < /tmp/filepruner_keepers.out
AFTERSIZE=$(du -sh | awk '{ print $1 }')

echo "Original size: $BEFORESIZE, New size: $AFTERSIZE"
