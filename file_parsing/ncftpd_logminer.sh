#!/bin/bash
# Requires bash 3 or greater
#
# 20071130 Jeff Gibson
# 20100908 JG updated for new comms cluster
# Script will find ncftpd log info for you.
# You can supply parameters to the command so you don't get so many
# prompts.  e.g.: startdate enddate logtype username process# server_node
# logminer -s 20071022 -e 20071023 -t sess -u username -p u8 -n myserver

# Assumes you have two ftp servers logging to different directories sharing
# the same base.  Each ftp server directory should be in the format of
# log.servername
# Example - /path/to/ftp_logs/log.server01/
#           /path_to/ftp_logs/log.server02/
# It should work fine with just one server, but that has not been tested.

# Of course, you will need to have the 'misc' logging turned on to be able to
# parse full ftp sessions.

# Set these
FTPLOGDIR=/path/to/ftp_logs
FTPSERVER1=server01
FTPSERVER2=server02

### FUNCTIONS

# This checks the year.  The only good values are the current year and
# prevoius year.
function testyear {
	YEAR=`date +%Y`
	if [ -z "$1" ] || [ "$1" -lt $(($YEAR -1)) ] || [ "$1" -gt "$YEAR" ] ; then
		echo "$1 is an invalid year"
		exit
	fi
}

# This checks for correct month numbers
function testmonth {
	if [ -z "$1" ] || [ "$1" -lt 1 ] || [ "$1" -gt 12 ] ; then
		echo $1 is an invalid month
		exit
	fi
}

# This checks for correct day numbers
function testday {
	# check for those annoying leap years
	testleap $3
	if [ $2 = 02 ] && [ "$LEAPYEAR" = "yes" ] && [ "$1" -gt "29" ] ; then
		echo "Day $1 does not exist in month $2"
		exit
	elif [ $2 = 02 ] && [ "$1" -gt "28" ] && [ "$LEAPYEAR" = "no" ] ; then
       		echo "Day $1 does not exist in month $2"
		exit
	fi
	if [[ $2 =~ (04|06|09|11) ]] && [ "$1" -gt "30" ] ; then
		echo "Day $1 does not exist in month $2"
		exit
	fi
        if [ -z "$1" ] || [ "$1" -lt 1 ] || [ "$1" -gt 31 ] ; then
                echo $1 is an invalid day
                exit
        fi
	unset LEAPYEAR
}

# Automatic leap year adjustment
function testleap {
	if [ $(($1 % 400)) = 0 ] ; then
       		LEAPYEAR=yes
	elif [ $(($1 % 100)) = 0 ] ; then
       		LEAPYEAR=no
	elif [ $(($1 % 4)) = 0 ] ; then
        	LEAPYEAR=yes
	else
        	LEAPYEAR=no
	fi
}

# OK, so this is what REALLY does the file processing
function grepper {
	if [ -f $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY ] ; then
		echo "PROCESSING $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY..."
		# misc logs are handled totally different than the other 2
		if [ "$LOGTYPE" = "misc" ] ; then
			# if no process numbers are listed than check everything.  Takes a while.
			if [ "$PROCESSNUMBER" = "all" ] ; then
				egrep "$USERNAME," $FTPLOGDIR/log.$2/sess.$1$PROMON$PRINTDAY | \
				awk '{ print $3 }' | sort -u | \
				while read i ; do
					grep $i\  $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY | \
					sed -e '/-------------------------------------------------/{x;p;x;}' | \
					sed -e '/./{H;$!d;}' -e 'x;/'"User \"$USERNAME\""'/!d;'
				done
			else
				# If a process number is supplied then just check that one.
				grep "\#$PROCESSNUMBER\ " $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY | \
                                sed -e '/-------------------------------------------------/{x;p;x;}' | \
                                sed -e '/./{H;$!d;}' -e 'x;/'"User \"$USERNAME\""'/!d;'
			fi
		else
			# sess and xfer logs are easier to process, just use the line below
			egrep "$USERNAME," $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY || \
			echo "$USERNAME not found in log $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY"
		fi
	else
		# if no log was found print an error
		echo "NOTICE!  Log $FTPLOGDIR/log.$2/$LOGTYPE.$1$PROMON$PRINTDAY does not exist!"
	fi	
}

# Print the day for the matches
function printday {
	# Add a zero in front of the month if needed
	if [[ $PROMON != ?? ]] ; then
		PROMON=0"$PROMON"
	fi
	# Add a zero in front of the day if needed
	if [ "$CURDAY" -lt 10 ] ; then
		PRINTDAY=0"$CURDAY"
	else
		PRINTDAY=$CURDAY
	fi
	# Which servers should we check the logs for?  Let's find out and then
	# call the grepper function
	if [ "$SERVERNAME" = "both" ] ; then
		SERVERS="$FTPSERVER1 $FTPSERVER2"
		for x in $SERVERS ; do
			grepper $1 $x
		done
	elif [ "$SERVERNAME" = "$FTPSERVER1" ] ; then
		grepper $1 $SERVERNAME
	elif [ "$SERVERNAME" = "$FTPSERVER2" ] ; then
		grepper $1 $SERVERNAME
	else
		echo $SERVERNAME is not valid
		exit
	fi
	# Lastly increment the day we're working on
	CURDAY=$(($CURDAY + 1))
}

# Day processing starts here
function mainprocess {
	# Set the Days if it's Feb.
	if [ "$PROMON" -eq 2 ] ; then
		testleap $1
		if [ $LEAPYEAR = yes ] ; then
			DAYS=29
		else
			DAYS=28
		fi
	# Set the Days for other 30 day months
	elif [[ "$PROMON" =~ (4|6|9|11) ]] ; then
		DAYS=30
	# Otherwise 31 days!
	else
		DAYS=31
	fi
	# If we're just working inside one month than set the correct end day
	if [ "$STMON" -eq "$ENMON" ] && [ "$STYEAR" -eq "$ENYEAR" ] ; then
		DAYS=$ENDAY
	fi
	# If it's the first month start on the right day
	if [ "$PROMON" -eq "$STMON" ] ; then
		CURDAY=$STDAY
		until [ "$CURDAY" -gt "$DAYS" ] ; do
			printday $1
		done
	# If it's the last month then end on the right day
	elif [ "$PROMON" -eq "$ENMON" ] ; then
		CURDAY=1
		until [ "$CURDAY" -gt "$ENDAY" ] ; do
			printday $1
		done
	# Otherwise we're between the start/stop months and all days get used
	else 
		CURDAY=1
        	until [ "$CURDAY" -gt "$DAYS" ] ; do
			printday $1
        	done
	fi
}

### LINEAR CODE

echo "Running.... Use the -h argument for more options or help"
while getopts "s:e:t:u:p:n:h" flag ; do
	case $flag in
		s )
			STR=$OPTARG
			;;
		e )
			END=$OPTARG
			;;
		t )
			LOGTYP=$OPTARG
			;;
		u )
			USR=$OPTARG
			;;
		p )
			PRS=$OPTARG
			;;
		n )
			BOX=$OPTARG
			;;
		h )
			echo
			echo "You can either just use the program without arguments and it will prompt"
			echo "you for the necessary info, or you can use the following:"
			echo
			echo "	-s	Start time, in format of YYYYMMDD"
			echo "	-e	End time, in format of YYYYMMDD (optional, if not supplied then"
			echo "		the script will assume it's the same as the start time)"
			echo "	-t	Log type.  Can either be sess, xfer, or misc"
			echo "	-u	Username.  The FTP user's account name"
			echo "	-p	Process number.  e.g. u8.  Process numbers are found in the sess"
			echo "		logs and are only needed for processing misc type logs"
			echo "		You can either specify one process name or \"all\""
			echo "	-n	Node.  What node to look for the logs on ($FTPSERVER1, $FTPSERVER2, or both)"
			echo "	-h	Help.  This message"
			exit
			;;
	esac
done

# Allow dates to be input as arguements or get prompted
#### This should be rewritten to use flags
if [ -n "$STR" ] ; then
	# set vars for first date
	STYEAR=`echo $STR | cut -c -4`
	STMON=`echo $STR | cut -c 5-6`
	STDAY=`echo $STR | cut -c 7-8`
	# If only one date is specified then assume it's only for one day
	# so, the endtime is the same as the startime
	if [ -z "$END" ] ; then
		ENYEAR=$STYEAR
		ENMON=$STMON
		ENDAY=$STDAY
	else
		ENYEAR=`echo $END | cut -c -4`
		ENMON=`echo $END | cut -c 5-6`
		ENDAY=`echo $END | cut -c 7-8`
	fi
# If no date was supplied let's ask the user for it
elif [ -z "$STR" ] ; then
	echo -n 'Enter starting year (e.g. 2007): '
	read STYEAR
	echo -n 'Enter starting month (e.g. 7 for July): '
	read STMON
	echo -n 'Enter starting day (e.g. 8): '
	read STDAY
	echo -n "Enter ending year: "
	read ENYEAR
	echo -n "Enter ending month: "
	read ENMON
	echo -n "Enter ending day: "
	read ENDAY
else
	# This should never happen but hey
	echo "that did not make sense at all!"
	exit
fi

# Check that the dates are sane
testyear $STYEAR
testmonth $STMON
testday $STDAY $STMON $STYEAR
testyear $ENYEAR
testmonth $ENMON
testday $ENDAY $ENMON $ENYEAR

# Get rid of preceding zeros, this seems like the simplest way
STMON=`expr $STMON - 1 + 1`
ENMON=`expr $ENMON - 1 + 1`
STDAY=`expr $STDAY - 1 + 1`
ENDAY=`expr $ENDAY - 1 + 1`

# If a logfile was specified set the var
if [ -n "$LOGTYP" ] ; then
	LOGTYPE=$LOGTYP
else
	# Otherwise prompt for it
	echo -n "Enter in logtype (xfer, sess, or misc): "
	read LOGTYPE
fi

# misc logs need more information
if [ "$LOGTYPE" = "misc" ] ; then
	if [ -z "$PRS" ] ; then
		# The process number is listed inside the sess and xfer logs.
		# it's useful for keeping sessions straight in the misc log.
		echo "Which process number do you want to look at? (e.g. u8)"
		echo -n "Or press enter for all: "
		read PROCESSNUMBER
		if [ -z "$PROCESSNUMBER" ] ; then
			PROCESSNUMBER=all
		fi
	else
		PROCESSNUMBER=$PRS
	fi
# sess and xfer logs don't need any more info
elif [ "$LOGTYPE" = "sess" ] ; then
	echo 
elif [ "$LOGTYPE" = "xfer" ] ; then
	echo 
# None of the above?  Then quit!
else 
	echo "Invalid log type, quitting"
	exit
fi

# Check for a supplied username.  otherwise prompt for it
if [ -n "$USR" ] ; then
	USERNAME=$USR
else
	echo -n "Enter ftp user's username: "
	read USERNAME
fi

# which server's logs are wanted?  Find out.
if [ -z "$BOX" ] ; then
	echo "Enter in ftp server's name ($FTPSERVER1, $FTPSERVER2)"
	echo -n "Or leave blank for both: "
	read SERVERNAME
	if [ -z "$SERVERNAME" ] ; then
		SERVERNAME=both
	fi
else
	SERVERNAME=$BOX
fi

# figure out the number of months to process
if [ "$STYEAR" -ne "$ENYEAR" ] ; then
	NUMMONTHS=$((12 + $ENMON - $STMON))
else
	NUMMONTHS=$(($ENMON - $STMON))
fi

# process all valid months for each valid year
CURMON=0
until [ "$CURMON" -gt "$NUMMONTHS" ] ; do
	# Current processing month is first month plus iteration number
	PROMON=$(($STMON + $CURMON))
	# No months exist over 12, so chop that number back down and send it to
	# the day processor
	if [ "$PROMON" -gt 12 ] ; then
		PROMON=$(($PROMON - 12))
		mainprocess $ENYEAR
	# otherwise just send the month number to the day processor
	else
		mainprocess $STYEAR
	fi
	# when done increment the iteration number
	CURMON=$(($CURMON + 1))
done
