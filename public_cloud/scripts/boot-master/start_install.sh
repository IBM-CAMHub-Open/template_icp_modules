#!/bin/bash
source /tmp/icp-bootmaster-scripts/functions.sh

if [ -f /opt/ibm/.image_version ]; then
  echo "cluster seems to already installed, exit now "
  exit 0
fi

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

verbosity=${2}

if docker run -e LICENSE=accept -e ANSIBLE_CALLBACK_WHITELIST=profile_tasks,timer --net=host -t -v /opt/ibm/cluster:/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} install ${verbosity} | tee /tmp/icp-install-log.txt; then

	iam=$(whoami)
	sudo rm -rf /opt/ibm/.image_version
	echo "${1}" | sudo tee -a /opt/ibm/.image_version
	sudo chown $iam /opt/ibm/.image_version
	
	exit ${PIPESTATUS[0]}
else
	exit ${PIPESTATUS[1]}
fi
