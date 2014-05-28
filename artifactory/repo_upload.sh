#!/bin/bash

BASEDIR='/rpm/centos'
RELEASE='6.5'
SYNCDIRS=( os updates )
URL='https://mycompany.artifactoryonline.com/mycompany'
REPO='ext-centos6-local'
UN='username'
PW='password'

cd $BASEDIR

for DIR in $SYNCDIRS ; do
	find $RELEASE/$DIR -type d | \
	while read i ; do
		curl -u $UN:$PW $URL/$REPO/$i/ -X PUT
	done

	find $RELEASE/$DIR -type f | \
	while read i ; do
		MD5=( $(md5sum $i) )
		SHA=( $(sha1sum $i) )
		curl -u $UN:$PW -X PUT $URL/$REPO/$i --data-binary "@$i" -H "X-Checksum-Sha1: ${SHA[0]}" -H "X-Checksum-Md5: ${MD5[0]}"
	done
done

cd -
