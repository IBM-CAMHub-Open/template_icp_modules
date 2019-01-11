#!/bin/bash

export ICP_VERSION=$1
export CURRENT_CLUSTER_DIR=$2
export DOCKER_REPO=`sudo docker images |grep "^ibmcom/icp-inception" |grep ${ICP_VERSION} |awk '{print $1}'`

setupClusterDirectory2103()
{
    cp -r ${CURRENT_CLUSTER_DIR}/cfc-certs ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    cp -r ${CURRENT_CLUSTER_DIR}/cfc-keys ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    cp -r ${CURRENT_CLUSTER_DIR}/cfc-components ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    cp ${CURRENT_CLUSTER_DIR}/hosts ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    cp ${CURRENT_CLUSTER_DIR}/ssh_key ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster

    sed -i -e 's/"vulnerability-advisor"/"va", "vulnerability-advisor"/g' ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    grep -Fxq "glusterfs: true" ${CURRENT_CLUSTER_DIR}/config.yaml && sed -i -e '/## GlusterFS Settings/a ## GlusterFs was true' ${CURRENT_CLUSTER_DIR}/config.yaml
    sed -i -e 's/^glusterfs: true/glusterfs: false/g' ${CURRENT_CLUSTER_DIR}/config.yaml
    echo "version: ${ICP_VERSION}" >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    #sed -e '1,/^version: \b/d' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    grep "^ingress_controller:" -q ${CURRENT_CLUSTER_DIR}/config.yaml && printf "nginx-ingress:\ningress:\nconfig:\n" >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    sed -n '/^disable-access-log:/p' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    sed -n '/^vip_iface:/p' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    sed -n '/^cluster_vip:/p' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    sed -n '/^proxy_vip_iface:/p' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
    sed -n '/^proxy_vip:/p' ${CURRENT_CLUSTER_DIR}/config.yaml >> ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster/config.yaml
}

upgradeTo2103()
{
    setupClusterDirectory2103

    cd ~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-prepare ; then
        printf "\033[32m[*] upgrade-prepare Succeeded \033[0m\n"
        if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-k8s ; then
            printf "\033[32m[*] upgrade-k8s Succeeded \033[0m\n"
            if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-mgtsvc ; then
                printf "\033[32m[*] upgrade-mgtsvc Succeeded \033[0m\n"
                if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-post ; then
                    printf "\033[32m[*] Upgraded to new ICP version \033[0m\n"
                    grep -Fxq "## GlusterFs was true" ${CURRENT_CLUSTER_DIR}/config.yaml && sed -i -e 's/^glusterfs: false/glusterfs: true/g' ${CURRENT_CLUSTER_DIR}/config.yaml
                    sed -i '/## GlusterFs was true/d' ${CURRENT_CLUSTER_DIR}/config.yaml
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
}

upgradeTo2103fp1()
{
    if docker run -e TMPDIR=/installer/cluster -e LICENSE=accept -t --net=host -v "$(pwd)":/installer/cluster ibmcom/icp-inception:2.1.0.3-ee ./cluster/ibm-cloud-private-2.1.0.3-fp1.sh ; then
        printf "\033[32m[*] Upgraded to new ICP version \033[0m\n"
    else
        printf "\033[31m[ERROR] Upgraded new ICP version Failed\033[0m\n"
        exit 1
    fi
}

setupClusterDirectory31x()
{
    ## Create and populate new cluster directory (exclude prior release ICP tar file)
    clusterDir31x=$1
    mkdir -p ${clusterDir31x}
    cd ${CURRENT_CLUSTER_DIR}
    find . -type d -name "images" -prune -o -type f -print | cpio -pdum ${clusterDir31x}
    rm -f ${clusterDir31x}/upgrade_version

    ## Ensure version is properly set in copied config.yaml file
    if grep -q "^version:" ${clusterDir31x}/config.yaml ; then
        sed -i -e "s/^version:.*/version: ${ICP_VERSION}/g" ${clusterDir31x}/config.yaml
    fi

    if [[ ${ICP_VERSION} == "3.1.0" ]] ; then
        ## Format of config.yaml differs in prior releases; Re-format enabled/disabled management services
        cd ${clusterDir}
        enabledServices="vulnerability-advisor"
        disabledServices="storage-glusterfs, storage-minio"
        currentDisabled=`grep -Po 'disabled_management_services: *\[\K[^\]]+' config.yaml | tr -d '",'`
        for service in ${currentDisabled}; do
            disabledServices="${disabledServices}, ${service}"
            enabledServices=`echo ${enabledServices} | sed -e "s/$service//"`
        done
        managementServices="management_services:\n"
        for service in `echo ${disabledServices} | tr -d ','`; do
            managementServices="${managementServices}  ${service}: disabled\n"
        done
        for service in `echo ${enabledServices} | tr -d ','`; do
            managementServices="${managementServices}  ${service}: enabled\n"
        done
        sed -i.bak -e "s/disabled_management_services: *\[.*/${managementServices}/" config.yaml
    fi
}

upgradeTo31x()
{
    clusterDir=~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster
    setupClusterDirectory31x ${clusterDir}

    cd ${clusterDir}
    if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-prepare ; then
        printf "\033[32m[*] upgrade-prepare Succeeded \033[0m\n"
        if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-k8s ; then
            printf "\033[32m[*] upgrade-k8s Succeeded \033[0m\n"
            if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee upgrade-chart ; then
                printf "\033[32m[*] upgrade-chart Succeeded \033[0m\n"
            else
                printf "\033[31m[ERROR] upgrade-chart Failed\033[0m\n"
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
}


if [[ ${ICP_VERSION} == "2.1.0.3" ]] ; then
    upgradeTo2103
elif [[ ${ICP_VERSION} == "2.1.0.3-fp1" ]] ; then
    upgradeTo2103fp1
elif [[ ${ICP_VERSION} == "3.1.0" ]] ; then
    upgradeTo31x
elif [[ ${ICP_VERSION} == "3.1.1" ]] ; then
    upgradeTo31x
else
    printf "\033[31m[ERROR] Unrecognized version; Unable to perform upgrade\033[0m\n"
    exit 1
fi