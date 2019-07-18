#!/bin/bash

# For Power env, if there are 32 or more CPUs, add the following settings to the IBM Cloud Private config.yaml file
# number of CPUs = vCPUs * SMT (SMT = 8 by default)
if [[ $2 == "3.1.1" ]] || [[ $2 == "3.1.2" ]]; then
  ppcimage=`docker images |grep icp-inception-ppc64le`
  numcpu=`cat /proc/cpuinfo | grep processor | wc -l`
  if [[ $numcpu -ge 32 && ! -z $ppcimage ]]; then
    tee -a $1/config.yaml << END
auth-idp:
  platform_auth:
    resources:
      limits:
        memory: 2500Mi
  identity_manager:
    resources:
      limits:
        memory: 2500Mi
  identity_provider:
    resources:
      limits:
        memory: 2500Mi
  icp_audit:
    resources:
      limits:
        memory: 1000Mi

auth-pap:
  auth_pap:
    resources:
      limits:
        memory: 2500Mi
  icp_audit:
    resources:
      limits:
        memory: 1000Mi

mariadb:
  mariadb:
    resources:
      limits:
        memory: 1000Mi
  mariadb_monitor:
    resources:
      limits:
        memory: 1000Mi

logging:
  logstash:
    memoryLimit: 3000Mi
  elasticsearch:
    client:
      memoryLimit: 3000Mi
    master:
      memoryLimit: 3000Mi
    data:
      memoryLimit: 4500Mi
  kibana:
    memoryLimit: 3000Mi
monitoring:
  prometheus:
    resources:
      limits:
        memory: 3000Mi
  alertmanager:
    resources:
      limits:
        memory: 1000Mi
  grafana:
    resources:
      limits:
        memory: 2000Mi
helm-api:
  helmapi:
    resources:
      limits:
        memory: 1000Mi
  rudder:
    resources:
      limits:
        memory: 1000Mi
  auditService:
    resources:
      limits:
        memory: 1000Mi
helm-repo:
  helmrepo:
    resources:
      limits:
        memory: 1500Mi
  auditService:
    resources:
      limits:
        memory: 1000Mi
mgmt-repo:
  mgmtrepo:
    resources:
      limits:
        memory: 1000Mi
  auditService:
    resources:
      limits:
        memory: 1000Mi
platform-api:
  platformApi:
    resources:
      limits:
        memory: 1000Mi
  platformDeploy:
    resources:
      limits:
        memory: 1000Mi
platform-ui:
  resources:
    limits:
      memory: 1000Mi
image-security-enforcement:
  resources:
    limits:
      memory: 1000Mi
catalog-ui:
  catalogui:
    resources:
      limits:
        memory: 1000Mi
service-catalog:
  service_catalog:
    apiserver:
      resources:
        limits:
          memory: 1000Mi
    controllerManager:
      resources:
        limits:
          memory: 1000Mi

nginx-ingress:
   ingress:
     config:
       disable-access-log: 'true'
       keep-alive-requests: '10000'
       upstream-keepalive-connections: '64'
       worker-processes: "5"
     extraArgs:
       publish-status-address: "{{ proxy_external_address }}"
       enable-ssl-passthrough: true
END
    if [[ $2 == "3.1.1" ]]; then
      echo 'kubelet_extra_args: ["--kube-reserved=cpu=500m,memory=1500Mi", "--system-reserved=cpu=500m,memory=1500Mi"]' >> $1/config.yaml
    fi
  fi
fi