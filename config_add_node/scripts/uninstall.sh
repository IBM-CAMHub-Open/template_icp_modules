#!/bin/bash

export DOCKER_REPO=`sudo docker images |grep inception |grep $1 |awk '{print $1}'`

function remove_glusterfs_node() {
    export HEKETI_POD=`kubectl -n kube-system get pod -l glusterfs=heketi-pod | grep "Running" | awk '{print $1}' | head -n 1`
    export ADMIN_PWD=`sed -n -e '/default_admin_password/ s/.*\: *//p' config.yaml`
    if [ -z "$HEKETI_POD" ] || [ -z "$ADMIN_PWD" ] ; then
        printf "\033[31m[ERROR] One or more variables are empty or undefined\033[0m\n"
        exit 1
    fi
    kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD node list | awk '{print $1}' | cut -d ':' -f 2 > current_glusterfs_nodes.txt
    while read line; do
        NODE_IP=`kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD node info $line | awk '/Storage Hostname:/,1' | cut -d ' ' -f 3`
        DEVICE_ID=`kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD node info $line | awk '/Devices/{getline; print}' | cut -d ' ' -f 1 | cut -d ':' -f 2`
        if [ -z "$NODE_IP" ] || [ -z "$DEVICE_ID" ] ; then
            printf "\033[31m[ERROR] One or more variables are empty or undefined\033[0m\n"
            exit 1
        fi
        if [[ $1 =~ $NODE_IP ]] ; then
            kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD device disable $DEVICE_ID
            kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD device remove $DEVICE_ID
            kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD device delete $DEVICE_ID
            kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD node delete $line
        fi
    done < current_glusterfs_nodes.txt
    printf "\033[32m[*] Remove Glusterfs Nodes Succeeded \033[0m\n"
    rm current_glusterfs_nodes.txt
}

if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$1-ee uninstall -l $2 ; then
    printf "\033[32m[*] Remove Node Succeeded \033[0m\n"
    if [[ $1 == "3.1.*" ]] ; then
        IFS=',' read -r -a iparray <<< $2
        for ip in "${iparray[@]}"
        do
            sed -i -e "/$ip/,+2d" config.yaml
        done
        printf "\033[32m[*] Cleanup config.yaml Succeeded \033[0m\n"
        remove_glusterfs_node $2
    fi
else
    printf "\033[31m[ERROR] Remove Node Failed\033[0m\n"
    exit 1
fi