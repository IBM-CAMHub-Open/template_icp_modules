#!/usr/bin/env bash

set -e

echo "Arg1 : $1"
echo "Arg1 : $2"
echo "Arg2 : $4"
echo "Arg3 : ${*:4}"
IPS=${*:4}
export GLUSTER_IPS=(${IPS})
export NUM_GLUSTER_BRICKS=${#GLUSTER_IPS[@]}

echo "$GLUSTER_IPS"
echo "$NUM_GLUSTER_BRICKS"

# for ((i=0; i < $NUM_GLUSTER_BRICKS; i++)); do
#   echo "          - ip: ${GLUSTER_IPS[i]}"
#   echo "            device: @@glusterfs@@"
# done
# Create Endpoint Based on Gluster Cluster IPs

if [[ $2 == 2.1.* ]] ; then
  glusterfs_txt=$(
    echo "glusterfs: true"
    echo "storage:"
    echo "  - kind: glusterfs"
    echo "    nodes:"
    for ((i=0; i < $NUM_GLUSTER_BRICKS; i++)); do
      echo "      - ip: ${GLUSTER_IPS[i]}"
      echo "        device: @@glusterfs@@"
    done
    echo "    storage_class:"
    echo "      default: true"
    echo "      name: glusterfs-storage"
    if [ $1 = "true" ]; then 
    echo "      volumetype: none"; 
    fi
  )
  echo "${glusterfs_txt}" > /tmp/$3/glusterfs.txt
else
  glusterfs_txt=$(
    echo "no_taint_group: [\"hostgroup-glusterfs\"]"
    echo "## GlusterFS Storage Settings"
    echo "storage-glusterfs:"
    echo "    nodes:"
    for ((i=0; i < $NUM_GLUSTER_BRICKS; i++)); do
      echo "      - ip: ${GLUSTER_IPS[i]}"
      echo "        devices:"
      echo "          - @@glusterfs@@"
    done
    echo "    storageClass:"
    echo "      create: true"
    echo "      name: glusterfs"
    echo "      isDefault: false"
    echo "      volumeType: replicate:$NUM_GLUSTER_BRICKS"
    echo "      reclaimPolicy: Delete"
    echo "      volumeBindingMode: Immediate"
    echo "      volumeNamePrefix: icp"
    echo "      additionalProvisionerParams: {}"
    echo "      allowVolumeExpansion: true"
    echo "    gluster:"
    echo "      resources:"
    echo "        requests:"
    echo "          cpu: 100m"
    echo "          memory: 128Mi"
    echo "        limits:"
    echo "          cpu: 200m"
    echo "          memory: 256Mi"
    echo "    heketi:"
    echo "      backupDbSecret: heketi-db-backup"
    echo "      authSecret: \"heketi-secret\""
    echo "      resources:"
    echo "        requests:"
    echo "          cpu: 500m"
    echo "          memory: 512Mi"
    echo "        limits:"
    echo "          cpu: 1000m"
    echo "          memory: 1Gi"
    echo "    prometheus:"
    echo "      enabled: false"
    echo "      path: \"/metrics\""
    echo "      port: 8080"
    echo "    nodeSelector:"
    echo "      key: hostgroup"
    echo "      value: glusterfs"
    echo "    podPriorityClass: \"system-cluster-critical\""
    echo "    tolerations: []"
    if [ $1 = "true" ]; then 
    echo "    volumetype: none"; 
    fi
  )
  echo "${glusterfs_txt}" > /tmp/$3/glusterfs.txt
fi