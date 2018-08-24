#!/bin/bash

if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-prepare ; then
    printf "\033[32m[*] upgrade-prepare Succeeded \033[0m\n"
    if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-k8s ; then
        printf "\033[32m[*] upgrade-k8s Succeeded \033[0m\n"
        if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-mgtsvc ; then
            printf "\033[32m[*] upgrade-mgtsvc Succeeded \033[0m\n"
            if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-post ; then
                printf "\033[32m[*] Upgraded to new ICP version \033[0m\n"
            else
                printf "\033[31m[ERROR] upgrade-post Failed\033[0m\n"
                exit 1
            fi
        else
            printf "\033[31m[ERROR] upgrade-mgtsvc Failed\033[0m\n"
            exit 1
        fi
    else
        printf "\033[31m[ERROR] upgrade-k8s Failed\033[0m\n"
        exit 1
    fi
else
    printf "\033[31m[ERROR] upgrade-prepare Failed\033[0m\n"
    exit 1
fi