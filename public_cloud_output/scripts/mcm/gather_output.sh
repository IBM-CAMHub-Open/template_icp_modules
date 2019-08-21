#!/bin/bash

#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

set -e

DOCKER=/etc/docker/certs.d
LOG_FILE=/tmp/gather_output.log
ICPDIR=/opt/ibm/cluster
PARAM_REG_PORT=8500
PARAM_CA_DOMAIN=$1

if [ -z "$PARAM_CA_DOMAIN" ]; then
	echo "CA Domain name is missing. Exit processing."
	exit 1
fi

DOCKER_CERT=${DOCKER}/${PARAM_CA_DOMAIN}:${PARAM_REG_PORT}/root-ca.crt
echo "Generate docker registry from ${DOCKER_CERT}" >> ${LOG_FILE}
#Init to base64(NIL)
DOCKER_CERT_BASE64=TklM
while true
do
	echo "Check if Docker file ${DOCKER_CERT} exists" >> ${LOG_FILE}
	if [[ -f "${DOCKER_CERT}" ]]; then
		DOCKER_CERT_BASE64=$(sudo cat ${DOCKER_CERT} | base64 -w0)
		break
	else
		echo "Docker file ${DOCKER_CERT} not found. Retry after 2 mts ... " >> ${LOG_FILE}
		sleep 120
	fi
done

echo "Output is:" >> ${LOG_FILE}
echo '{"docker_cert":"'"${DOCKER_CERT_BASE64}"'"}' >> ${LOG_FILE}
echo '{"docker_cert":"'"${DOCKER_CERT_BASE64}"'", "install_dir":"'"${ICPDIR}"'"}'
