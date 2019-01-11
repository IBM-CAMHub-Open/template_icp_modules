#!/bin/bash

export ICP_VERSION=$1
export CLUSTER_NAME=$2
export API_SERVER_PORT=$3
export MASTER_NODE_IP=$4
export DOCKER_REPO=`sudo docker images |grep "^ibmcom/icp-inception" |grep ${ICP_VERSION} |awk '{print $1}'`

rollback2103()
{
    if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster $DOCKER_REPO:${ICP_VERSION}-ee rollback-mgtsvc ; then
        printf "\033[32m[*] rollback-mgtsvc succeeded \033[0m\n"
        export kubernetes_apiserver_url=https://${MASTER_NODE}:${API_SERVER_PORT}

        sudo docker run -e LICENSE=accept --net=host -v /usr/local/bin:/data $DOCKER_REPO:${ICP_VERSION}-ee cp /usr/local/bin/kubectl /data
        kubectl config set-cluster ${CLUSTER_NAME} --server=$kubernetes_apiserver_url --insecure-skip-tls-verify=true
        kubectl config set-context ${CLUSTER_NAME} --cluster=${CLUSTER_NAME}
        kubectl config set-credentials ${CLUSTER_NAME} --client-certificate=./cfc-certs/kubecfg.crt --client-key=./cfc-certs/kubecfg.key
        kubectl config set-context ${CLUSTER_NAME}  --user=${CLUSTER_NAME}
        kubectl config use-context ${CLUSTER_NAME}

        kubectl delete jobs monitoring-monitoring-cert-delete-job --ignore-not-found=true -n kube-system
        kubectl delete secret monitoring-monitoring-ca-cert monitoring-monitoring-certs monitoring-monitoring-client-certs --ignore-not-found=true -n kube-system

        if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster $DOCKER_REPO:${ICP_VERSION}-ee upgrade-mgtsvc ; then
            printf "\033[32m[*] upgrade-mgtsvc succeeded \033[0m\n"
        else
            sudo docker run -v $(pwd):/data -e LICENSE=accept $DOCKER_REPO:2.1.0.3-ee cp /usr/local/bin/helm /data
            mv helm /usr/local/bin/
            helm init -c --stable-repo-url /tmp
            cp ./cfc-certs/helm/admin.crt /cert.pem
            cp ./cfc-certs/helm/admin.key /key.pem
            kubectl -n kube-system get pods -l app=helm,name=tiller
            helm list --tls
            for chart in $(ls .addon); do helm delete --tls --timeout=600 --purge $chart; done
            kubectl delete jobs auth-idp-platform-auth-cert-gen helm-api-helm-cert-gen-job helm-api-helm-service-onboard-job monitoring-monitoring-cert-delete-job --ignore-not-found=true -n kube-system
            kubectl delete jobs auth-db-migrate helmapi-db-migrate helmrepo-db-migrate metering-db-migrate --ignore-not-found=true -n kube-system
            kubectl delete cm/auth-idp-platform-auth-cert-gen --ignore-not-found=true -n kube-system
            kubectl delete secret icp-mongodb-client-cert platform-auth-secret monitoring-monitoring-ca-cert monitoring-monitoring-certs monitoring-monitoring-client-certs --ignore-not-found=true -n kube-system
            rm -rf /var/lib/icp/mongodb/
        fi

        if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster $DOCKER_REPO:${ICP_VERSION}-ee rollback-k8s ; then
            printf "\033[32m[*] Rollback ICP Version Succeeded \033[0m\n"
        else
            printf "\033[31m[ERROR] rollback-k8s Failed\033[0m\n"
            exit 1
        fi
    else
        printf "\033[31m[ERROR] rollback-mgtsvc Failed\033[0m\n"
        exit 1
    fi
}

rollback2103fp1()
{
    if sudo docker run -e LICENSE=accept -t --net=host -v "$(pwd)":/installer/cluster $DOCKER_REPO:2.1.0.3-ee ./cluster/ibm-cloud-private-2.1.0.3-fp1.sh -- rollback ; then
        printf "\033[32m[*] Rollback ICP Version Succeeded \033[0m\n"
    else
        printf "\033[31m[ERROR] Rollback ICP Version Failed\033[0m\n"
        exit 1
    fi
}

rollback31x()
{
    clusterDir=~/ibm-cloud-private-x86_64-${ICP_VERSION}/cluster

    cd ${clusterDir}
    if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee rollback-chart ; then
        printf "\033[32m[*] rollback-chart Succeeded \033[0m\n"
        if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${DOCKER_REPO}:${ICP_VERSION}-ee rollback-k8s ; then
            printf "\033[32m[*] rollback-k8s Succeeded \033[0m\n"
        else
            printf "\033[31m[ERROR] rollback-k8s Failed\033[0m\n"
            exit 1
        fi
    else
        printf "\033[31m[ERROR] rollback-chart Failed\033[0m\n"
        exit 1
    fi
}


if [[ ${ICP_VERSION} == "2.1.0.3" ]] ; then
    rollback2103
elif [[ ${ICP_VERSION} == "2.1.0.3-fp1" ]] ; then
    rollback2103fp1
elif [[ ${ICP_VERSION} == "3.1.0" ]] ; then
    rollback31x
elif [[ ${ICP_VERSION} == "3.1.1" ]] ; then
    rollback31x
else
    printf "\033[31m[ERROR] Unrecognized version; Unable to perform rollback\033[0m\n"
    exit 1
fi