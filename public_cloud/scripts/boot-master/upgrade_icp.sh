#!/bin/bash

echo "enter upgrade_icp for ${1}, image is ${2}"

source /tmp/icp-bootmaster-scripts/functions.sh

ICPDIR=/opt/ibm/cluster

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}

IMAGE_VERSION=none
IMAGE_VERSION_PATH=/opt/ibm/.image_version
if [ -f $IMAGE_VERSION_PATH ]; then
	IMAGE_VERSION=`cat $IMAGE_VERSION_PATH`
fi

echo "IMAGE_VERSION=$IMAGE_VERSION"

if [ "$IMAGE_VERSION" == "${1}" ]; then
  echo "cluster seems to already be at version ${tag}, exit now "
  exit 0
fi


echo "tag=${tag} repo=${repo}"

OLDICPDIR=/opt/${tag}
if [ -d $OLDICPDIR ]; then
  echo "found folder $OLDICPDIR so cluster seems to already be at version ${tag}, exit now "
  exit 0
fi

if [[ ${tag} =~ "ee" ]]; then

    
	IMAGE_LOCATION=$(basename ${2})
	echo "IMAGE_LOCATION=$IMAGE_LOCATION"
	IMAGE_FILE_PATH=$ICPDIR/images/$IMAGE_LOCATION
	
	echo "this is the ee version, waiting for file $IMAGE_FILE_PATH"
	END=140
	x=$END
	while [ $x -gt 0 ]; 
	do 
		x=$(($x-1))	
	    if [ -f $IMAGE_FILE_PATH ]; then
	      echo "$IMAGE_FILE_PATH is available, break now"
	      break
	    else
	      echo "$IMAGE_FILE_PATH is not available, sleep 60s"
	      sleep 60  
	    fi
	    
	done
else
	echo "this is the ce version, continue"
fi

sudo mkdir -p $OLDICPDIR
cd $OLDICPDIR
sudo cp -r $ICPDIR .
sudo rm -rf cluster/.upgrade

cd $ICPDIR
sudo rm -rf .upgrade

calico_ipip_enabled=$(awk '/calico_ipip_enabled/ {print $2}' ${ICPDIR}/config.yaml)
echo "check calico_ipip_enabled=$calico_ipip_enabled"

if [ -z $calico_ipip_enabled ]; then
  echo "calico_ipip_enabled was not set"
else
  echo "calico_ipip_enabled was set to $calico_ipip_enabled, remove it"
  sed -i '/calico_ipip_enabled/d' ${ICPDIR}/config.yaml
  
  if [ "$calico_ipip_enabled" == "true" ]; then
     echo "set calico_ipip_mode: Always"
     sed -i -e '$a'"calico_ipip_mode: Always" ${ICPDIR}/config.yaml
  else
     echo "set calico_ipip_mode: Never"  
     sed -i -e '$a'"calico_ipip_mode: Never" ${ICPDIR}/config.yaml  
  fi 
fi

echo "run sudo docker run -e LICENSE=accept --net=host --rm -t -v $(pwd):/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-prepare"
if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-prepare; then

	printf "\033[32m[*] Upgrade-prepare step had succeeded \033[0m\n"
	
	echo "run sudo docker run -e LICENSE=accept --net=host --rm -t -v $(pwd):/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-k8s"
	if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-k8s; then

		printf "\033[32m[*] upgrade-k8s step had succeeded \033[0m\n"

		echo "run sudo docker run -e LICENSE=accept --net=host --rm -t -v $(pwd):/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-chart"
		if sudo docker run -e LICENSE=accept --net=host --rm -t -v "$(pwd)":/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} upgrade-chart; then
			printf "\033[32m[*] upgrade-chart step had succeeded \033[0m\n"

			echo "TODO delete obsolete charts"
			#helm delete --purge --tls --timeout=600  mariadb
			#helm delete --purge --tls --timeout=600  heapster
			#helm delete --purge --tls --timeout=600  unified-router
			#helm delete --purge --tls --timeout=600  auth-apikeys
		
		else
		    printf "\033[31m[ERROR] Failed to run upgrade-k8s step\033[0m\n"
		    exit 1  		
		fi
	else
	    printf "\033[31m[ERROR] Failed to run upgrade-k8s step\033[0m\n"
	    exit 1  
	fi
	
else
    printf "\033[31m[ERROR] Failed to run upgrade-prepare step\033[0m\n"
    exit 1  
fi

sudo rm -rf /opt/ibm/.image_version
echo "${1}" | sudo tee -a /opt/ibm/.image_version


