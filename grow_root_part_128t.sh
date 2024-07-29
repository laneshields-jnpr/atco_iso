#!/bin/bash

# grow_root_part_128t.sh originally for expanding /dev/vda3 on KVM deployments
# generalized to support all underlying LVM device types for ODM

## configuration

VOLGRP=vg00
ROOTVOL=root

ROOTLV=/dev/$VOLGRP/$ROOTVOL

# write logs/status on /boot as only that is available if called from initramfs
OUTFILE=/boot/grow_root_part_128t

## functions

checkrc()
{
  rc=$?
  if [ $rc -ne 0 ]
  then
     echo "FAIL: $1 [$rc]" | tee -a $OUTFILE.log
     touch $OUTFILE.failed
     exit $rc
  else
     echo "DONE: $1 [$rc,$2]" >> $OUTFILE.log
  fi
}

expand_partition () {
    if growpart --dry-run /dev/$SDEV $NPART | grep -q NOCHANGE
    then
        echo "Root partition does not need to be expanded."
    else
        echo "Attempting to expand root parition."
        growpart /dev/$SDEV $NPART
        checkrc "growing /dev/$SDEV $NPART"
    fi

    # Extend physical volume to fill root partition (may be no-op)
    lvm pvresize -y /dev/$SPART
    checkrc "resizing /dev/$SPART"

    # extend primary root volume to 100% of physical volume
    lvm lvresize -y -r -l 100%VG $ROOTLV
    checkrc "resizing $ROOTLV"
}

## initialization

# remove any old tag files
rm -f $OUTFILE.failed
rm -f $OUTFILE.done

echo "BEFORE: " >> $OUTFILE.log
pvscan >> $OUTFILE.log
lvscan >> $OUTFILE.log

# find device map of root logical volume - e.g dm-0
DM=$(udevadm info -q name $ROOTLV)
checkrc "getting device map for $ROOTLV" $DM

# find partition hosting root volume group - e.g. sda2, nvme0n1p2
# note: does not support spanned volumes
SPART=$(ls -1 /sys/devices/virtual/block/$DM/slaves/)
checkrc "finding volume group $VOLGRP" $SPART

# find device hosting the partition - e.g. sda, nvme0n1
SDEV=$(readlink /sys/class/block/$SPART)
SDEV=${SDEV%/*}
SDEV=${SDEV##*/}
checkrc "getting parent device of $SPART" $SDEV

# find partition index for the root volume - e.g. 2
NPART=$(cat /sys/block/$SDEV/$SPART/partition)
checkrc "getting partition number for $SDEV $SPART" $NPART


## main

FORCE=false

while :; do
  case $1 in
    --force)
      FORCE=true
      ;;
    -?*)
      echo "ERROR: Invalid option: -$1" >&2
      echo "Exiting..."
      exit 1
      ;;
    *)
      break
  esac
  shift
done

if [ "$FORCE" == "true" ] ; then
    echo "Found force flag."
    expand_partition
fi

if [ "$FORCE" != "true" ] ; then
    echo "This Application will attempt to expand the root partition on $ROOTLV"
    while true; do
        read -p "Do you wish to continue? [y/n]:  " input
        case $input in
            [Yy]*) expand_partition
                   break
                   ;;
            [Nn]*) echo "Aborting..."
                   exit 0
                   ;;
            *) echo "Please answer yes or no."
               ;;
        esac
    done
fi

## cleanup

echo "AFTER: " >> $OUTFILE.log
pvscan >> $OUTFILE.log
lvscan | tee -a $OUTFILE.log

touch $OUTFILE.done
exit 0
