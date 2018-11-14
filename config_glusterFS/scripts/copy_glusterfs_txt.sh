#!/bin/bash

set -x

while test $# -gt 0; do
  [[ $1 =~ ^-i|--bootip ]] && { BOOT_IP="${2}"; shift 2; continue; };
  [[ $1 =~ ^-p|--password ]] && { BOOT_PASSWORD="${2}"; shift 2; continue; };
  break;
done

# Check if a command exists
function command_exists() {
  type "$1" &> /dev/null;
}


function check_command_and_install() {
    command=$1
    string="[*] Checking installation of: $command"
    line="......................................................................."
    if command_exists $command; then
      printf "%s %s [INSTALLED]\n" "$string" "${line:${#string}}"
    else
      printf "%s %s [MISSING]\n" "$string" "${line:${#string}}"
        if [ $# == 3 ]; then # If the package name is provided
          if [[ $PLATFORM == *"ubuntu"* ]]; then
            sudo apt-get update -y
            sudo apt-get install -y $2
          else
            sudo yum install -y $3
          fi
        else # If a function name is provided
          eval $2
        fi
        if [ $? -ne "0" ]; then
          echo "[ERROR] Failed while installing $command"
          exit 1
        fi
    fi
}

# Identify the platform and version using Python
if command_exists python; then
    PLATFORM=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
    PLATFORM_VERSION=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
else
    if command_exists python3; then
        PLATFORM=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
        PLATFORM_VERSION=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
    fi
fi
# Change the string 'redhat' to 'rhel'
if [[ $PLATFORM == *"redhat"* ]]; then
    PLATFORM="rhel"
fi


## Install sshpass package
check_command_and_install sshpass sshpass sshpass

## Gather key for boot host
ssh-keyscan ${BOOT_IP} | sudo tee -a  ~/.ssh/known_hosts

## Send glusterfs file to boot host
sshpass -p ${BOOT_PASSWORD} scp /tmp/glusterfs.txt ${BOOT_IP}:~/
