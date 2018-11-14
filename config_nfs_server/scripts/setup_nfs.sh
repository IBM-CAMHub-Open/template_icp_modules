#!/bin/bash

while test $# -gt 0; do
  [[ $1 =~ ^-d|--drive ]]     && { DRIVE="${2}"; shift 2; continue; };
  [[ $1 =~ ^-l|--dynamic ]]   && { FOLDERS="${2}"; shift 2; continue; };
  break;
done

IFS=',' read -a myfolderarray <<< "${FOLDERS}"

function wait_apt_lock()
{
    sleepC=5
    while [[ -f /var/lib/dpkg/lock  || -f /var/lib/apt/lists/lock ]]
    do
      sleep $sleepC
      echo "    Checking lock file /var/lib/dpkg/lock or /var/lib/apt/lists/lock"
      [[ `sudo lsof 2>/dev/null | egrep 'var.lib.dpkg.lock|var.lib.apt.lists.lock'` ]] || break
      let 'sleepC++'
      if [ "$sleepC" -gt "50" ] ; then
 	lockfile=`sudo lsof 2>/dev/null | egrep 'var.lib.dpkg.lock|var.lib.apt.lists.lock'|rev|cut -f1 -d' '|rev`
        echo "Lock $lockfile still exists, waited long enough, attempt apt-get. If failure occurs, you will need to cleanup $lockfile"
        continue
      fi
    done
}

# Check if a command exists
function command_exists() {
  type "$1" &> /dev/null;
}

# Create and mount NFS file system
function create_file_system() {
    MOUNT_POINT="/var/nfs"
    # format and mount a drive to /mnt
    echo "Formatting drive $DRIVE"
    sudo mkfs.ext3 -F $DRIVE
    echo "Creating folder for mount point: $MOUNT_POINT"
    sudo mkdir -p $MOUNT_POINT
    echo "Adding $DRIVE to /etc/fstab"
    echo "$DRIVE  $MOUNT_POINT ext3  defaults 1 3" | sudo tee -a /etc/fstab
    echo ""
    echo "Setting mount point permissions and mounting"
    if [[ $PLATFORM == *"ubuntu"* ]]; then
        sudo chown nobody:nogroup $MOUNT_POINT
    elif [[ $PLATFORM == *"rhel"* ]]; then
        sudo chown nobody:nobody $MOUNT_POINT
    fi
    sudo mount $MOUNT_POINT
}

# Install the NFS server, depending upon the platform
function install_nfs_server() {
    echo "Installing NFS server"
    if [[ $PLATFORM == *"ubuntu"* ]]; then
        wait_apt_lock
        sudo apt-get update -y
        wait_apt_lock
        sudo apt-get install -y nfs-kernel-server
    elif [[ $PLATFORM == *"rhel"* ]]; then
        sudo yum -y install nfs-utils rpcbind
        sudo systemctl enable nfs-server
        sudo systemctl enable rpcbind
        sudo systemctl enable nfs-lock
        sudo systemctl enable nfs-idmap
    fi
}

# Create mount points for NFS directories
function create_nfs_mount_points() {
    echo "Creating mount points"
    export NUM_FOLDERS=${#myfolderarray[@]}

    for ((i=0; i < ${NUM_FOLDERS}; i++)); do
        last_folder=`echo ${myfolderarray[i]} | awk -F/ '{print $NF}'`
        if [ ! -d "$MOUNT_POINT/$last_folder" ]; then
            echo "$MOUNT_POINT/$last_folder doesn't exist, creating..."
            sudo mkdir -p $MOUNT_POINT/$last_folder
        fi
        echo "$MOUNT_POINT/$last_folder  *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    done
}

# Restart the NFS server, depending upon the platform
function start_nfs_server() {
    echo "Starting NFS server"
    if [[ $PLATFORM == *"ubuntu"* ]]; then
        sudo systemctl restart nfs-kernel-server
    elif [[ $PLATFORM == *"rhel"* ]]; then
        sudo systemctl restart rpcbind
        sudo systemctl restart nfs-server
        sudo systemctl restart nfs-lock
        sudo systemctl restart nfs-idmap
        sudo systemctl status nfs
    fi
}

# Identify the platform and version using Python
PLATFORM="unknown"
if command_exists python; then
    PLATFORM=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
    PLATFORM_VERSION=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
else
    if command_exists python3; then
        PLATFORM=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
        PLATFORM_VERSION=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
    fi
fi
if [[ $PLATFORM == *"redhat"* ]]; then
    PLATFORM="rhel"
fi

# Perform tasks to setup NFS server
create_file_system
install_nfs_server
create_nfs_mount_points
start_nfs_server