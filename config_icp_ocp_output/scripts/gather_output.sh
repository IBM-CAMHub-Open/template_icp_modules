#!/bin/bash

#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

set -e

CLIENT_CERTIFICATE=/etc/cfc/conf/kubecfg.crt
CLIENT_KEY=/etc/cfc/conf/kubecfg.key
DOCKER=/etc/docker/certs.d
LOG_FILE=/tmp/gather_output.log

while test $# -gt 0; do
  [[ $1 =~ ^-c|--cluster ]] && { PARAM_CLUSTER_NAME="${2}"; shift 2; continue; };
  [[ $1 =~ ^-as|--apisrvr ]] && { PARAM_API_SERVER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-ap|--apiport ]] && { PARAM_API_PORT="${2}"; shift 2; continue; };
  [[ $1 =~ ^-rs|--regsrvr ]] && { PARAM_REG_SERVER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-rp|--regport ]] && { PARAM_REG_PORT="${2}"; shift 2; continue; };
  [[ $1 =~ ^-u|--user ]] && { PARAM_ADMIN_USER="${2}"; shift 2; continue; };
  break
done

if [ -z "$PARAM_ADMIN_USER" ]; then
	echo "Admin username is missing. Use default value admin." >> ${LOG_FILE}
	PARAM_ADMIN_USER=admin
fi

if [ -z "$PARAM_CLUSTER_NAME" ]; then
	echo "Cluster name is missing" >> ${LOG_FILE}
	exit 1
fi

if [ -z "$PARAM_API_SERVER" ]; then
	echo "API server name is missing" >> ${LOG_FILE}
	exit 1
fi

if [ -z "$PARAM_API_PORT" ]; then
	echo "API server port is missing" >> ${LOG_FILE}
	exit 1
fi

echo "Generate kube certificate data" >> ${LOG_FILE}
CLIENT_CERTIFICATE_BASE64=$(sudo cat ${CLIENT_CERTIFICATE} | base64 -w0)
CLIENT_KEY_BASE64=$(sudo cat ${CLIENT_KEY} | base64 -w0)

echo "construct kube config" >> ${LOG_FILE}	
sed -i -e "s/@@cluster@@/${PARAM_CLUSTER_NAME}/" /tmp/config_template
sed -i -e "s/@@apiserver@@/${PARAM_API_SERVER}/" /tmp/config_template
sed -i -e "s/@@apiport@@/${PARAM_API_PORT}/" /tmp/config_template
sed -i -e "s/@@client-certificate@@/${CLIENT_CERTIFICATE_BASE64}/" /tmp/config_template
sed -i -e "s/@@client-key@@/${CLIENT_KEY_BASE64}/" /tmp/config_template
sed -i -e "s/@@user@@/${PARAM_ADMIN_USER}/" /tmp/config_template

echo "Generate kube config" >> ${LOG_FILE}
CONFIG_BASE64=$(cat /tmp/config_template | base64 -w0)

DOCKER_CERT=${DOCKER}/${PARAM_REG_SERVER}:${PARAM_REG_PORT}/node-client-ca.crt
echo "Generate docker registry from ${DOCKER_CERT}" >> ${LOG_FILE}
#Init to base64(NIL)
DOCKER_CERT_BASE64=TklM
if [[ -f "${DOCKER_CERT}" ]]; then
	DOCKER_CERT_BASE64=$(sudo cat ${DOCKER_CERT} | base64 -w0)
else
	echo "Docker file ${DOCKER_CERT} not found" >> ${LOG_FILE}
fi

#No CA cert data required for VMware. Set it to base64(NIL)
KUBE_CA_CERT_DATA=TklM

echo "Output is:" >> ${LOG_FILE}
echo '{"config":"'"${CONFIG_BASE64}"'","config_ca_cert_data":"'"${KUBE_CA_CERT_DATA}"'","docker_cert":"'"${DOCKER_CERT_BASE64}"'"}' >> ${LOG_FILE}
echo '{"config":"'"${CONFIG_BASE64}"'","config_ca_cert_data":"'"${KUBE_CA_CERT_DATA}"'","docker_cert":"'"${DOCKER_CERT_BASE64}"'"}'
