#!/bin/bash

# Path to the LSI MegaRAID storcli command
STORCLI="/opt/MegaRAID/storcli/storcli64"

# Affinity prefixes
AFFPFX=( 1 2 4 8 )
# Interrupts use by megaraid controllers
INTERRUPTS=$(grep mega /proc/interrupts  | awk -F: '{ print $1 }')
RUN=0

# Exit if we didn't find any megaraids
if [ -z "${INTERRUPTS[0]}" ] ; then
	echo "No MegaRAID controllers found, exiting"
	exit
fi

# Set the affinity for each megaraid interrupt
echo "Setting the CPU affinity for MegaRAID interrupts..."
declare END
for int in ${INTERRUPTS[@]} ; do 
		FIRSTEL="${AFFPFX[0]}"
		echo "Setting /proc/irq/$int/smp_affinity to ${FIRSTEL}${END}"
		echo ${FIRSTEL}${END} > /proc/irq/$int/smp_affinity
		# Now shift the array
		unset AFFPFX[0]
		AFFPFX=( "${AFFPFX[@]}" "$FIRSTEL" )
		# Each time we find an '8' add another 0 to the end of the string
		if [ "$FIRSTEL" == '8' ] ; then
			END=${END}0
		fi
		# Have to reset affinity values after 80000000
		if [ "${FIRSTEL}${END}" = "80000000" ] ; then
			unset END FIRSTEL APPPFX
			AFFPFX=( 1 2 4 8 )
		fi
done
echo

# Set irq banned interrupts for irqbalance
echo -n "Checking banned interrupts for irqbalance daemon... "
IRQLIST=${INTERRUPTS[*]}
#echo interrupts are  $IRQLIST
grep -q "^IRQBALANCE_BANNED_INTERRUPTS=$IRQLIST" /etc/sysconfig/irqbalance
if [ "$?" != "0" ] ; then
	echo "updating"
	#echo "IRQBALANCE_BANNED_INTERRUPTS='$IRQLIST'"
	sed -i "s/^#\?IRQBALANCE_BANNED_INTERRUPTS=.*/IRQBALANCE_BANNED_INTERRUPTS=$IRQLIST/g" /etc/sysconfig/irqbalance
	service irqbalance restart
else
	echo "good"
fi

# Detect # of controllers
# Grab the number with the lsi command
echo -n "Finding LSI MegaRAID controllers, "
CTRLCOUNT=$($STORCLI show ctrlcount | grep Controller | awk '{ print $4 }')
if [ -z "$CTRLCOUNT" ] ; then
	echo "No LSI-branded MegaRAID Controllers found.  Exiting"
	exit
else
	echo "found $CTRLCOUNT"
fi

# Convert the count to an array
CTLRS=( $(for ((i=0; i < $CTRLCOUNT; i++)) ; do echo $i ; done) )
#echo ctlrs are ${CTLRS[@]}

# Run once for each controller
echo
for CTRLNUM in ${CTLRS[@]} ; do
	# Find which controller we are on that will match with lsscsi
	PCI=$($STORCLI /c$CTRLNUM show all | grep 'PCI Address' | awk '{ print $4 }' | sed -e 's/^/00/g' -e 's/:00$/\.0/g')
	echo "Setting vg properties for controller $CTRLNUM at PCI address $PCI..."

	# Get a list of the drive IDs
	DRIVEIDS=( $(ls -d /sys/bus/pci/devices/$PCI/host[0-9]/target* | sed -e 's/^.*target//g' -e 's/$/:0/g' | grep -E -v "[[:digit:]]*:0:[[:digit:]]*:0") )
	#echo "The following SCSI addresses were found for controller $CTRLNUM:"
	#echo ${DRIVEIDS[@]}

	# Get the LSI VG IDs
	VGIDS=$($STORCLI /c$CTRLNUM/vall show | grep '/' | grep -v 'TYPE' | grep -v 'Cac'| awk -F'/' '{ print $1 }')

	# Detect SSD VGs on the controller
	declare -a SSDS
	while read i ; do
		$STORCLI /c$CTRLNUM/v$i show all | grep -q SSD
		if [ "$?" = "0" ] ; then
			SSDS=( "${SSDS[@]}" "$i" )
		fi
		export SSDS
	done <<< "${VGIDS[@]}"
	#[[ -n "${SSDS[@]}" ]] && echo "Volume group(s) ${SSDS[@]} appear to be SSDs" || echo "No SSDS VGs found"
	unset i

	# Get the adapter and channel numbers we are using
	TMPIFS="$IFS"
	IFS=':'
	SCSIID=( ${DRIVEIDS[0]} )
	IFS="$TMPIFS"
	#echo SCSIID is ${SCSIID[@]}
	ADPCHN="${SCSIID[0]}:${SCSIID[1]}"
	#echo ADPCHN is $ADPCHN

	# Get drive names
	declare -a DRNAMES
	for i in ${SSDS[@]} ; do
		MYDRIVE=$(lsscsi | grep $(for j in ${DRIVEIDS[@]} ; do echo $j ; done | grep -E "$ADPCHN:$i:[[:digit:]]") | awk '{ print $6 }')
		#echo mydrive is $MYDRIVE
		#MYDRIVE=$(lsscsi | grep LSI | grep -E $i | awk '{ print $6 }')
		DRNAMES=( "${DRNAMES[@]}" "$MYDRIVE" )
	done
	#[[ -n ${DRNAMES[@]} ]] && echo "Drives ${DRNAMES[@]} appear to be SSDs"
	unset j
	unset i

	# Basename the drives
	declare -a DRIVESHORT
	for i in ${DRNAMES[@]} ; do
		BASENAME=$(basename $i)
		#echo $BASENAME
		DRIVESHORT=( "${DRIVESHORT[@]}" "$BASENAME" )
	done
	export DRIVESHORT
	#echo drive basenames are ${DRIVESHORT[@]}
	unset i

	# Now we can finally set stuff for the SSDS
	if [[ -n ${DRIVESHORT[0]} && ${DRIVESHORT[0]} != "" ]] ; then
		echo "Disabling rotational optimizations for SSD VGs ${DRIVESHORT[@]}"
		for i in ${DRIVESHORT[@]} ; do
			#echo setting driveshort $i
			echo 0 > /sys/block/$i/queue/rotational
		done
		unset i
	fi

	# Set stuff for all drives
	DRIVENAMES=( $(lsscsi | grep `for id in ${DRIVEIDS[@]} ; do echo "-e $id " ; done` | awk '{ print $6 }' ) )
	echo "Applying LSI recommendations to $(for i in ${DRIVENAMES[@]} ; do basename $i ; done | tr '\n' ' ')"
	echo
	for i in ${DRIVENAMES[@]} ; do
		DRIVE=$(basename $i)
		# deadline should alredy be set, but shouldn't hurt
		echo deadline > /sys/block/$DRIVE/queue/scheduler
		echo 0 > /sys/block/$DRIVE/queue/rq_affinity
		echo 975 > /sys/block/$DRIVE/queue/nr_requests
		echo 975 > /sys/block/$DRIVE/device/queue_depth
	done
	unset id
	unset i
	unset SSDS VGIDS DRIVEIDS DRNAMES DRIVESHORT ADPCHN SCSIID MYDRIVE
	echo
done

# non-drive specific stuff
# Turn off kworkd001 CPU eating background kernel thread
#echo N > /sys/module/drm_kms_helper/parameters/poll
