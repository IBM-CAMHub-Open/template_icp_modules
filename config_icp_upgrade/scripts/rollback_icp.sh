#!/bin/bash

if [[ $1 == "2.1.0.3-fp1" ]] ; then
    if docker run -e LICENSE=accept -t --net=host -v "$(pwd)":/installer/cluster ibmcom/icp-inception:2.1.0.3-ee ./cluster/ibm-cloud-private-2.1.0.3-fp1.sh -- rollback ; then
        printf "\033[32m[*] Rollback ICP Version Succeeded \033[0m\n"
    else
        printf "\033[31m[ERROR] Rollback ICP Version Failed\033[0m\n"
        exit 1
    fi
else
    if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee rollback-mgtsvc ; then
        printf "\033[32m[*] rollback-mgtsvc succeeded \033[0m\n"
        export cluster_name=$2
        [ -z $5 ] && export kubernetes_apiserver_url=https://$4:$3 || export kubernetes_apiserver_url=https://$5:$3

        docker run -e LICENSE=accept --net=host -v /usr/local/bin:/data ibmcom/icp-inception:$1-ee cp /usr/local/bin/kubectl /data
        kubectl config set-cluster $cluster_name --server=$kubernetes_apiserver_url --insecure-skip-tls-verify=true
        kubectl config set-context $cluster_name --cluster=$cluster_name
        kubectl config set-credentials $cluster_name --client-certificate=./cfc-certs/kubecfg.crt --client-key=./cfc-certs/kubecfg.key
        kubectl config set-context $cluster_name  --user=$cluster_name
        kubectl config use-context $cluster_name

        kubectl delete jobs monitoring-monitoring-cert-delete-job --ignore-not-found=true -n kube-system
        kubectl delete secret monitoring-monitoring-ca-cert monitoring-monitoring-certs monitoring-monitoring-client-certs --ignore-not-found=true -n kube-system

        if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee upgrade-mgtsvc ; then
            printf "\033[32m[*] upgrade-mgtsvc succeeded \033[0m\n"
        else
            docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception:2.1.0.3-ee cp /usr/local/bin/helm /data
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

        if docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:$1-ee rollback-k8s ; then
            printf "\033[32m[*] Rollback ICP Version Succeeded \033[0m\n"
        else
            printf "\033[31m[ERROR] rollback-k8s Failed\033[0m\n"
            exit 1
        fi
    else
        printf "\033[31m[ERROR] rollback-mgtsvc Failed\033[0m\n"
        exit 1
    fi
fi