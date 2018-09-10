#!/bin/bash

if [[ $1 == "2.1.0.3-fp1" ]] ; then
    if docker run -e TMPDIR=/installer/cluster -e LICENSE=accept -t --net=host -v "$(pwd)":/installer/cluster ibmcom/icp-inception:2.1.0.3-ee ./cluster/ibm-cloud-private-2.1.0.3-fp1.sh ; then
        printf "\033[32m[*] Upgraded to new ICP version \033[0m\n"
    else
        printf "\033[31m[ERROR] Upgraded new ICP version Failed\033[0m\n"
        exit 1
    fi
else
    cp -r $2/cfc-certs /root/ibm-cloud-private-x86_64-$1/cluster
    cp -r $2/cfc-keys /root/ibm-cloud-private-x86_64-$1/cluster
    cp -r $2/cfc-components /root/ibm-cloud-private-x86_64-$1/cluster
    cp $2/hosts /root/ibm-cloud-private-x86_64-$1/cluster
    cp $2/ssh_key /root/ibm-cloud-private-x86_64-$1/cluster

    sed -i -e 's/"vulnerability-advisor"/"va", "vulnerability-advisor"/g' /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    grep -Fxq "glusterfs: true" $2/config.yaml && sed -i -e '/## GlusterFS Settings/a ## GlusterFs was true' $2/config.yaml
    sed -i -e 's/^glusterfs: true/glusterfs: false/g' $2/config.yaml
    echo "version: $1" >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    #sed -e '1,/^version: \b/d' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    grep "^ingress_controller:" -q $2/config.yaml && printf "nginx-ingress:\ningress:\nconfig:\n" >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    sed -n '/^disable-access-log:/p' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    sed -n '/^vip_iface:/p' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    sed -n '/^cluster_vip:/p' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    sed -n '/^proxy_vip_iface:/p' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml
    sed -n '/^proxy_vip:/p' $2/config.yaml >> /root/ibm-cloud-private-x86_64-$1/cluster/config.yaml

    if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-prepare ; then
        printf "\033[32m[*] upgrade-prepare Succeeded \033[0m\n"
        if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-k8s ; then
            printf "\033[32m[*] upgrade-k8s Succeeded \033[0m\n"
            if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-mgtsvc ; then
                printf "\033[32m[*] upgrade-mgtsvc Succeeded \033[0m\n"
                if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-post ; then
                    printf "\033[32m[*] Upgraded to new ICP version \033[0m\n"
                    grep -Fxq "## GlusterFs was true" $2/config.yaml && sed -i -e 's/^glusterfs: false/glusterfs: true/g' $2/config.yaml
                    sed -i '/## GlusterFs was true/d' $2/config.yaml
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
fi