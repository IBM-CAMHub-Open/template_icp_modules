#!/bin/bash

export DOCKER_REPO=`sudo docker images |grep inception |grep $5 |awk '{print $1}'`

function config_kubectl() {
    printf "\033[32m[*] Configuring kubectl...... \033[0m\n"
    sudo docker run -e LICENSE=accept --net=host -v /usr/local/bin:/data $DOCKER_REPO:$2-ee cp /usr/local/bin/kubectl /data
    export MASTER_IP=`awk 'f{print;f=0} /\[master\]/{f=1}' $1/hosts`
    export CLUSTER_NAME=`sed -n -e '/# cluster_name/ s/.*\: *//p' $1/config.yaml`
    if [ -z "$MASTER_IP" ] || [ -z "$CLUSTER_NAME" ] ; then
        printf "\033[31m[ERROR] One or more variables are empty or undefined\033[0m\n"
        exit 1
    else
        kubectl config set-cluster $CLUSTER_NAME --server=https://$MASTER_IP:8001 --insecure-skip-tls-verify=true
        kubectl config set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME
        if [[ $2 == "3.1.0" ]] ; then
           kubectl config set-credentials $CLUSTER_NAME --client-certificate=./cfc-certs/kubecfg.crt --client-key=./cfc-certs/kubecfg.key
        else
           kubectl config set-credentials $CLUSTER_NAME --client-certificate=./cfc-certs/kubernetes/kubecfg.crt --client-key=./cfc-certs/kubernetes/kubecfg.key
        fi
        kubectl config set-context $CLUSTER_NAME  --user=$CLUSTER_NAME
        kubectl config use-context $CLUSTER_NAME
        printf "\033[32m[*] Configure kubectl Succeeded \033[0m\n"
    fi
}

function add_storage_node() {
    if [ -z $1 ] ; then
        printf "\033[31m[ERROR] No list of VMs found \033[0m\n"
        exit 1
    fi
    export EXISTING_GlusterFS_POD=$3
    if [ -z "$EXISTING_GlusterFS_POD" ] ; then
        printf "\033[31m[ERROR] No existing glusterfs pod found \033[0m\n"
        exit 1
    fi
    while read line; do
        if kubectl -n kube-system exec $EXISTING_GlusterFS_POD -- gluster peer probe $line ; then
            printf "\033[32m[*] Peer probe $line Succeeded \033[0m\n"
            sleep 20
        else
            printf "\033[31m[ERROR] Peer probe $line Failed \033[0m\n"
            exit 1
        fi
    done < $1
    export HEKETI_POD=`kubectl -n kube-system get pod -l glusterfs=heketi-pod | grep "Running" | awk '{print $1}' | head -n 1`
    export ADMIN_PWD=`sed -n -e '/default_admin_password/ s/.*\: *//p' $2/config.yaml`
    export CLUSTER_ID=`kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD cluster list | grep "Id:" | cut -d ' ' -f 1 | cut -d ':' -f 2`
    sleep 20
    if [ -z "$HEKETI_POD" ] || [ -z "$ADMIN_PWD" ] || [ -z "$CLUSTER_ID" ] ; then
        printf "\033[31m[ERROR] One or more variables are empty or undefined\033[0m\n"
        exit 1
    fi
    while read line; do
        NODE_ID=`kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD node add --zone=1 --cluster=$CLUSTER_ID --management-host-name=$line --storage-host-name=$line | awk '/Node information:/{getline; print}' | cut -d ' ' -f 2`
        SYMLINK=`grep -A 2 $line $2/config.yaml | sed -e '1,2d' | sed -n -e '/-/ s/.*\  *//p'`
        sleep 20
        if kubectl -n kube-system exec $HEKETI_POD -- heketi-cli --user admin --secret $ADMIN_PWD device add --name=$SYMLINK --node=$NODE_ID ; then
            printf "\033[32m[*] Update topology for $line Succeeded \033[0m\n"
            sleep 20
        else
            printf "\033[31m[ERROR] Update topology for $line Failed \033[0m\n"
            exit 1
        fi
    done < $1
}

if [[ $2 == "worker" ]] ; then
    if [ -e $3 ] ; then
        if [[ $5 == "2.1.*" ]] ; then
            if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$5-ee worker -l $6 ; then
                printf "\033[32m[*] Add Node Succeeded \033[0m\n"
                if $1 ; then
                    mv $4/config.yaml $4/config.yaml_temp
                    cp $3 $4/config.yaml
                    if sudo docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster $DOCKER_REPO:$5-ee install-glusterfs -vv | tee gluster_install.txt ; then
                        rm $4/config.yaml
                        mv $4/config.yaml_temp $4/config.yaml
                        printf "\033[32m[*] Configure GlusterFS Succeeded \033[0m\n"
                    else
                        rm $4/config.yaml
                        mv $4/config.yaml_temp $4/config.yaml
                        printf "\033[31m[ERROR] Configure GlusterFS Failed\033[0m\n"
                        exit 1
                    fi
                fi
            else
                printf "\033[31m[ERROR] Add Node Failed\033[0m\n"
                exit 1
            fi
        else
            if [[ $1 == "false" ]] ; then
                if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$5-ee worker -l $6 ; then
                    printf "\033[32m[*] Add Node Succeeded \033[0m\n"
                else
                    printf "\033[31m[ERROR] Add Node Failed\033[0m\n"
                    exit 1
                fi
            else
                sed -n -e '/nodes:/,/storageClass:/ p' $3 | sed -e '1d;$d' > new_glusterfs_nodes.txt
                sed -i -e '/^    nodes:/r new_glusterfs_nodes.txt' $4/config.yaml
                sed -n -e '/- ip/ s/.*\: *//p' new_glusterfs_nodes.txt > new_glusterfs_vms.txt
                (grep -q '\[hostgroup-glusterfs\]' $4/hosts && sed -i -e '/\[hostgroup-glusterfs\]/r new_glusterfs_vms.txt' $4/hosts) || (echo '[hostgroup-glusterfs]' >> $4/hosts && sed -i -e '/\[hostgroup-glusterfs\]/r new_glusterfs_vms.txt' $4/hosts)
                #sed -i -e '/\[hostgroup-glusterfs\]/r new_glusterfs_vms.txt' $4/hosts
                config_kubectl $4 $5
                sleep 20
                sudo  chown $7 -R $4
                EXISTING_GlusterFS=`kubectl -n kube-system get pod -owide -l glusterfs=pod | grep "Running" | awk '{print $1}' | head -n 1`
                #sed -i -e '/\[worker\]/r new_glusterfs_vms.txt' $4/hosts
                if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$5-ee hostgroup -l $6 ; then
                    printf "\033[32m[*] Add host to GlusterFS host group Succeeded \033[0m\n"
                else
                    printf "\033[31m[ERROR] Add host to GlusterFS host group Failed, Add Node Failed\033[0m\n"
                    exit 1
                fi
                sleep 2m
                add_storage_node new_glusterfs_vms.txt $4 $EXISTING_GlusterFS
                rm new*.txt
                printf "\033[32m[*] Configure GlusterFS Succeeded \033[0m\n"
            fi
        fi
    else
        printf "\033[31m[ERROR] No gluster.txt Found, Configure GlusterFS Failed\033[0m\n"
        exit 1
    fi
else
    if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$5-ee $2 -l $6 ; then
        printf "\033[32m[*] Add Node Succeeded \033[0m\n"
    else
        printf "\033[31m[ERROR] Add Node Failed\033[0m\n"
        exit 1
    fi
fi