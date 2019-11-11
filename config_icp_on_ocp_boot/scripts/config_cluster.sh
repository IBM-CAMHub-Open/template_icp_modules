#!/bin/bash

icp_master_host=$1
icp_proxy_host=$2
icp_management_host=$3
ocp_console_fqdn=$4
ocp_vm_domain_name=$5
icp_version=$6
ocp_enable_glusterfs=$7
ocp_console_port=$8

sudo cp /etc/origin/master/admin.kubeconfig /opt/ibm-cloud-private-rhos-${icp_version}/cluster/kubeconfig

sed -i -e '/cluster_node/,+16 d' /opt/ibm-cloud-private-rhos-${icp_version}/cluster/config.yaml

FILE=/etc/ansible/hosts
if test -f "$FILE"; then
  ocp_version="3"
  ocp_router=$(sed -n '/openshift_master_default_subdomain/p' /etc/ansible/hosts | cut -d '=' -f 2)
else
  ocp_version="4"
  ocp_router=$5
fi

#generate config file
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
  elif uname -a | grep -i "X86" > /dev/null; then
    echo "storage_class: ibmc-file-gold"
  elif uname -a | grep -i "ppc64le" > /dev/null; then
    echo "storage_class: ibmc-powervc-k8s-volume-default"
  else
    echo "storage_class: generic"
  fi
  echo ""
  echo "openshift:"
  echo "  console:"
  echo "    host: ${ocp_console_fqdn}"
  echo "    port: ${ocp_console_port}"
  echo "  router:"
  echo "    cluster_host: icp-console.${ocp_router}"
  echo "    proxy_host: icp-proxy.${ocp_router}"
)

echo "${config_file}" >> /opt/ibm-cloud-private-rhos-${icp_version}/cluster/config.yaml

#ssh key
yum -y install sshpass
sshpass ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ${icp_master_host}.${ocp_vm_domain_name}
sshpass ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ${icp_proxy_host}.${ocp_vm_domain_name}
sshpass ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ${icp_management_host}.${ocp_vm_domain_name}

# run installer
cd /opt/ibm-cloud-private-rhos-${icp_version}/cluster
sudo docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z -v /etc/docker:/etc/docker:z --security-opt label:disable ibmcom/icp-inception-amd64:${icp_version}-rhel-ee install-with-openshift | tee /tmp/install.log; test $${PIPESTATUS[0]} -eq 0

# send certificate to all other nodes
if [[ $ocp_version == "3" ]]; then
  scp -r /etc/docker/certs.d/docker-registry-default* root@${icp_master_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
  scp -r /etc/docker/certs.d/docker-registry-default* root@${icp_proxy_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
  scp -r /etc/docker/certs.d/docker-registry-default* root@${icp_management_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
elif [[ $ocp_version == "4" ]]; then
  scp -r /etc/docker/certs.d/docker-registry-default* core@${icp_master_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
  scp -r /etc/docker/certs.d/docker-registry-default* core@${icp_proxy_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
  scp -r /etc/docker/certs.d/docker-registry-default* core@${icp_management_host}.${ocp_vm_domain_name}:/etc/docker/certs.d
fi  