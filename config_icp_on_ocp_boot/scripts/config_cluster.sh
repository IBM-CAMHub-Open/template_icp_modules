#!/bin/bash

icp_master_host=$1
icp_proxy_host=$2
icp_management_host=$3
ocp_master_host=$4
ocp_vm_domain_name=$5
icp_version=$6
ocp_enable_glusterfs=$7

sudo cp /etc/origin/master/admin.kubeconfig /opt/ibm-cloud-private-rhos-${icp_version}/cluster/kubeconfig

sed -i -e '/cluster_node/,+16 d' /opt/ibm-cloud-private-rhos-${icp_version}/cluster/config.yaml

ocp_router=$(sed -n '/openshift_master_default_subdomain/p' /etc/ansible/hosts | cut -d '=' -f 2)

if [[ $ocp_enable_glusterfs == "false" ]]; then
  cat > generic-gce.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: generic
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  zone: us-east1-d
EOF
  oc create -f generic-gce.yaml
  oc new-project rh-eng
  cat > pvc-fast.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: pvc-engineering
spec:
 accessModes:
  - ReadWriteMany
 resources:
   requests:
     storage: 35Gi
 storageClassName: generic
EOF
  oc create -f pvc-fast.yaml
fi

config_file=$(
  echo "cluster_nodes:"
  echo "  master:"
  echo "    - ${icp_master_host}.${ocp_vm_domain_name}"
  echo "  proxy:"
  echo "    - ${icp_proxy_host}.${ocp_vm_domain_name}"
  echo "  management:"
  echo "    - ${icp_management_host}.${ocp_vm_domain_name}"
  echo ""
  if [[ $ocp_enable_glusterfs == "true" ]]; then
    echo "storage_class: glusterfs-storage"
  else
    echo "storage_class: generic"
  fi
  echo ""
  echo "openshift:"
  echo "  console:"
  echo "    host: ${ocp_master_host}.${ocp_vm_domain_name}"
  echo "    port: 8443"
  echo "  router:"
  echo "    cluster_host: icp-console.${ocp_router}"
  echo "    proxy_host: icp-proxy.${ocp_router}"
)

echo "${config_file}" >> /opt/ibm-cloud-private-rhos-${icp_version}/cluster/config.yaml