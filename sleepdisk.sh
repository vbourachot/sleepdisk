#!/bin/sh

# sleepdisks.sh:
# Puts specified drive(s) in standby when no read/write activity occurs over
# a configurable period of time (somewhere between SLEEP_TIME and SLEEP_TIME*2)
# Do this as simply as possible (25 lines or less) while supporting md arrays

# Interval to check for inactivity (in seconds)
SLEEP_TIME=900
SELF=`basename $0`

monitorDisk() {
  # get initial io read / io writes
  ior=`awk -v disk=$logical_disk '{if ($3==disk) print $6}' /proc/diskstats`
  iow=`awk -v disk=$logical_disk '{if ($3==disk) print $10}' /proc/diskstats`

  sleep $SLEEP_TIME

  # if disk(s) not in standby && new_ior == ior && new_iow == iow, sleep
  while :; do
	  # skip if the array is being resynced (does not show in diskstats)
	  if [ -f '/proc/mdstat' ] && grep -q $logical_disk /proc/mdstat \
			&& grep -q -e 'resync' -e 'check' /proc/mdstat; then
		  sleep $SLEEP_TIME
		  continue
	  fi
      hdparm -C /dev/$physical_disks | grep -q 'active' >/dev/null 2>&1
      # $? == 0 if any disk is active, 1 if all disks are in standby
      if [ $? -ne 1 ]; then
          new_ior=`awk -v disk=$logical_disk '{if ($3==disk) print $6}' /proc/diskstats`
          new_iow=`awk -v disk=$logical_disk '{if ($3==disk) print $10}' /proc/diskstats`
          if [ $new_ior -eq $ior ] && [ $new_iow -eq $iow ]; then
              logger "$SELF: Putting $physical_disks in standby"
              hdparm -y /dev/$physical_disks >/dev/null 2>&1
          fi
          ior=$new_ior
          iow=$new_iow
      fi
      sleep $SLEEP_TIME
  done
}

check_root() {
  if [ $(id -u) -ne 0 ]; then
     echo "This script must run as root as it relies on hdparm"
     echo ""
     usage
     exit 1
  fi
}

usage() {
  echo "Usage: 	$SELF logical_disk physical_disk"
  echo "	logical_disk	logical drive name to check for read/writes"
  echo "	physical_disk	actual drive name(s) to put in standby when there is "
  echo "			no activity on the logical disk"
  echo ""
  echo "Example:		$SELF sdb sdb"
  echo "			$SELF md0 sd[c-d]"
  exit 1
}

check_root
if [ "$#" -ne 2 ]; then
  usage
else
  logical_disk=$1
  physical_disks=$2
  logger "$SELF: Monitoring $logical_disk; will standby $physical_disks when inactive"
  monitorDisk $logical_disk $physical_disks
fi
