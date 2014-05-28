#!/bin/bash
# safedelete.sh
# 20110711 JG
# Finds logs older than $KEEP_DAYS days, makes sure they're not open, then deletes
LOG_PATH="/u01/app/oracle/product/ohs/Apache/Apache/logs"
LOGNAMES="*log*"
KEEP_DAYS="7"

# We're probably running from this dir already, but make it just in case
mkdir -p "$HOME"/bin
# Reset my own log file
echo "Last run `date`" > "$HOME"/bin/safe_delete.log
# Find logs
find "$LOG_PATH" -name "$LOGNAMES" -mtime +"$KEEP_DAYS" | \
# Load them into a loop
while read LOGFILE ; do
        # Remove files if not open
        /sbin/fuser -ms "$LOGFILE"
        if [ "$?" != "0" ] ; then
                rm -v "$LOGFILE" >> "$HOME"/bin/safe_delete.log
        fi
done

