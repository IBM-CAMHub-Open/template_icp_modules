#!/bin/bash

# set -x
set -e

while test $# -gt 0; do
  [[ $1 =~ ^-i|--icpversion$ ]] && { icpversion="$2"; shift 2; continue; };
  [[ $1 =~ ^-r|--random$ ]] && { random="$2"; shift 2; continue; };
  [[ $1 =~ ^-m|--master$ ]] && { masterip="$2"; shift 2; continue; };
  [[ $1 =~ ^-p|--proxy$ ]] && { proxyip="$2"; shift 2; continue; };
  [[ $1 =~ ^-w|--worker$ ]] && { workerip="$2"; shift 2; continue; };
  [[ $1 =~ ^-v|--va$ ]] && { vaip="$2"; shift 2; continue; };
  [[ $1 =~ ^-g|--gpfs$ ]] && { gpfs="$2"; shift 2; continue; };
  [[ $1 =~ ^-n|--management$ ]] && { shift 1; };
  [[ $1 =~ ^- ]] && continue || { managementip="$1"; shift 1; continue; };
    shift
done

IFS=',' read -a mymasterarray <<< "${masterip}"
IFS=',' read -a mymanagementarray <<< "${managementip}"
IFS=',' read -a myproxyarray <<< "${proxyip}"
IFS=',' read -a myworkerarray <<< "${workerip}"
IFS=',' read -a myvaarray <<< "${vaip}"

export NUM_MASTER=${#mymasterarray[@]}
export NUM_MANAGEMENT=${#mymanagementarray[@]}
export NUM_PROXY=${#myproxyarray[@]}
export NUM_WORKER=${#myworkerarray[@]}
export NUM_VA=${#myvaarray[@]}

echo "$NUM_MASTER"
echo "$NUM_MANAGEMENT"
# Create Endpoint Based on Gluster Cluster IPs

#KUB_CMDS="kubelet_extra_args='[\"--eviction-hard=memory.available<100Mi,nodefs.available<2Gi,nodefs.inodesFree<5\"]',\"--image-gc-high-threshold=100\",\"--image-gc-low-threshold=100\""

icp_hosts_txt=$(
  if [ ${NUM_MANAGEMENT} -gt 0 ]
  then
    echo '[management]'
    for ((i=0; i < ${NUM_MANAGEMENT}; i++)); do
      echo "${mymanagementarray[i]}"
    done
  fi
  echo "[master]"
  for ((i=0; i < ${NUM_MASTER}; i++)); do
    echo "${mymasterarray[i]}"
  done
  echo "[proxy]"
  for ((i=0; i < ${NUM_PROXY}; i++)); do
    echo "${myproxyarray[i]}"
  done
  echo "[worker]"
  for ((i=0; i < ${NUM_WORKER}; i++)); do
    echo "${myworkerarray[i]}"
  done
  if [ ${NUM_VA} -gt 0 ]
  then
    echo '[va]'
    for ((i=0; i < ${NUM_VA}; i++)); do
      echo "${myvaarray[i]}" 
    done
  fi
  if [ ${gpfs} == true ] && [[ ${icpversion} != 2.1.* ]]
  then
    echo "[hostgroup-glusterfs]"
    for ((i=0; i < ${NUM_WORKER}; i++)); do
      echo "${myworkerarray[i]}"
    done
  fi
)

echo "/tmp/${random}/icp_hosts"

echo "${icp_hosts_txt}" > /tmp/${random}/icp_hosts