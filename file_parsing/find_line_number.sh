#!/bin/bash

# Get the line number from a list of files, search for the fist line for a file that has not yet been deleted.

INFILE="$1"
FILECOUNT=$(wc -l $INFILE | awk '{ print $1}')
ORIGCOUNT=$FILECOUNT
LASTCHECK=$FILECOUNT

KEEPSEARCHING=true

function checkforfile {
	CHKFILE=$(head -$CHECKNUM "$INFILE" | tail -1)
	stat -t "$CHKFILE" &> /dev/null
	echo $?
}
	

while [ "$KEEPSEARCHING" = "true" ] ; do
	CHECKNUM=$FILECOUNT
	RESULT=$(checkforfile)
	if [ "$RESULT" = "0" ] ; then
		echo "Testing line $FILECOUNT"
		# See if the prev file exists too.  var name is wrong
		CHECKNUM=$(($FILECOUNT - 1))
		CHKNEXTNUM=$(checkforfile)
		if [ "$CHKNEXTNUM" = "0" ] ; then
			# next file exits, keep going
			LSTMP=$FILECOUNT
			STARTCOUNT=$((LASTCHECK - $FILECOUNT))
			[[ "$STARTCOUNT" -lt "0" ]] && STARTCOUNT=$(($STARTCOUNT * -1))
			FILECOUNT=$((($STARTCOUNT/2) - $FILECOUNT))
			[[ "$FILECOUNT" -lt "0" ]] && FILECOUNT=$(($FILECOUNT * -1))
			LASTCHECK=$LSTTMP
			echo "File exists.  New line to test is $FILECOUNT"
		else
			echo "Line $FILECOUNT is the last file"
			KEEPSEARCHING="false"
		fi
	else	
		LSTTMP=$FILECOUNT
		#FILECOUNT=$(($FILECOUNT / 2 + $FILECOUNT))
		STARTCOUNT=$(($LASTCHECK - $FILECOUNT))
		[[ "$STARTCOUNT" -lt "0" ]] && STARTCOUNT=$(($STARTCOUNT * -1))
		FILECOUNT=$((($STARTCOUNT/2) + $FILECOUNT))
		echo "File not found.  New line to test is $FILECOUNT"
		LASTCHECK=$LSTTMP
	fi
	usleep 50000
done
