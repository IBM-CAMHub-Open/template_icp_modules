#!/bin/bash

if $1 && [[ $2 == "worker" ]] ; then
    if [ -e $3 ] ; then
        mv $4/config.yaml $4/config.yaml_temp
        cp $3 $4/config.yaml
        if sudo docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$5-ee install-glusterfs -vv | tee gluster_install.txt ; then
            rm $4/config.yaml
            mv $4/config.yaml_temp $4/config.yaml
            printf "\033[32m[*] Configure GlusterFS Succeeded \033[0m\n"
        else
            rm $4/config.yaml
            mv $4/config.yaml_temp $4/config.yaml
            printf "\033[31m[ERROR] Configure GlusterFS Failed\033[0m\n"
            exit 1
        fi
    else
        printf "\033[31m[ERROR] No gluster.txt Found, Configure GlusterFS Failed\033[0m\n"
        exit 1
    fi
else
    printf "\033[32m[*] No GlusterFS configured\033[0m\n"
fi