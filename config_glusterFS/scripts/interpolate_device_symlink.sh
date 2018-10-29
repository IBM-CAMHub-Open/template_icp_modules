#!/bin/bash
#
# This will locate a set of iunformatted disks
#set -x
function find_disk()
{
  # Will return an unallocated disk, it will take a sorting order from largest to smallest, allowing a the caller to indicate which disk
  [[ -z "$1" ]] && whichdisk=1 || whichdisk=$1
  local readonly=`parted -l 2>&1 | egrep -i "Warning:" | tr ' ' '\n' | egrep "/dev/" | sort -u | xargs -i echo "{}|" | xargs echo "NONE|" | tr -d ' ' | rev | cut -c2- | rev`
  diskcount=`sudo parted -l 2>&1 | egrep -v "$readonly" | egrep -c -i 'ERROR: '`
  if [ "$diskcount" -lt "$whichdisk" ] ; then
        echo ""
  else
        # Find the disk name
        greplist=`sudo parted -l 2>&1 | egrep -v "$readonly" | egrep -i "ERROR:" |cut -f2 -d: | xargs -i echo "Disk.{}:|" | xargs echo | tr -d ' ' | rev | cut -c2- | rev`
        echo `sudo fdisk -l  | egrep "$greplist"  | sort -k5nr | head -n $whichdisk | tail -n1 | cut -f1 -d: | cut -f2 -d' '`
  fi
}

whichdisk=`find_disk | cut -f3 -d'/'`
devpath=`udevadm info --root --name=/dev/$whichdisk | grep DEVPATH | cut -f2 -d'='`
devtype=`udevadm info --root --name=/dev/$whichdisk | grep DEVTYPE | cut -f2 -d'='`
subsystem=`udevadm info --root --name=/dev/$whichdisk | grep SUBSYSTEM | cut -f2 -d'='`
symlink="gluster-disk-$whichdisk"
sudo touch /lib/udev/rules.d/10-custom-icp.rules
echo "ENV{DEVTYPE}==\"$devtype\", ENV{SUBSYSTEM}==\"$subsystem\", ENV{DEVPATH}==\"$devpath\" SYMLINK+=\"disk/$symlink\"" | sudo tee -a /lib/udev/rules.d/10-custom-icp.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --type=devices --action=change

manual_symbolic_link=$(echo "/dev/disk/$symlink" | sed 's/\//\\\//g')
cp /tmp/glusterfs.txt /tmp/glusterfs.txt.backup
sed -i "s/@@glusterfs@@/$manual_symbolic_link/g" /tmp/glusterfs.txt
