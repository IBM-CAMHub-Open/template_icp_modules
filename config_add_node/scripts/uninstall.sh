#!/bin/bash

export DOCKER_REPO=`sudo docker images |grep inception |grep $1 |awk '{print $1}'`

if sudo docker run -e LICENSE=accept --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:$1-ee uninstall -l $2 ; then
    printf "\033[32m[*] Remove Node Succeeded \033[0m\n"
    if [[ $1 == "3.1.0" ]] ; then
        IFS=',' read -r -a iparray <<< $2
        for ip in "${iparray[@]}"
        do
            sed -i -e "/$ip/,+2d" config.yaml
        done
        printf "\033[32m[*] Cleanup config.yaml Succeeded \033[0m\n"
    fi
else
    printf "\033[31m[ERROR] Remove Node Failed\033[0m\n"
    exit 1
fi