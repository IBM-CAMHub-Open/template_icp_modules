#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec  > $LOGFILE 2>&1

echo "Image $1"
echo "image_file $2"
echo "image_location $3"
echo "registry_server $4"
echo "registry_username $5"

image=$1
image_file=$2
image_location=$3
registry_server=$4
registry_username=$5
registry_password=$6
sourcedir=/opt/ibm/cluster/images

source /tmp/icp-bootmaster-scripts/functions.sh

echo "load-image.sh image=${image} image_location=${image_location} image_file=${image_file}"

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${image}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

if [ -f ${sourcedir}/${image_file} ]; then
 	echo "image file seems to have been already loaded to ${sourcedir}/${image_file}, do nothing"
  exit 0

fi

if [[ "${image_location}" != "false" ]]
then
  # Decide which protocol to use
  if [[ "${image_location:0:3}" == "nfs" ]]
  then
    # Separate out the filename and path
    nfs_mount=$(dirname ${image_location:4})
    image_file="${sourcedir}/$(basename ${image_location})"
    mkdir -p ${sourcedir}
    # Mount
    sudo mount.nfs $nfs_mount $sourcedir
  elif [[ "${image_location:0:4}" == "http" ]]
  then
    # Figure out what we should name the file
    filename="ibm-cloud-private-x86_64-${tag%-ee}.tar.gz"
    mkdir -p ${sourcedir}
    wget --continue -O ${sourcedir}/${filename} "${image_location}"
    image_file="${sourcedir}/${filename}"
  fi
fi

if [[ -s "$image_file" ]]
then
  echo "Unpacking ${image_file} ..."
  pv --interval 10 ${image_file} | tar zxf - -O | sudo docker load
  
  mkdir -p ${sourcedir}
  sudo mv ${image_file} /opt/ibm/cluster/images/
  iam=$(whoami)
  sudo chown $iam -R /opt/ibm/cluster/images   

  if [ -z "${registry_server}" ]; then
	
	 echo "No internal registry server setup exit now"
	 exit 0
  fi   
	
  sudo mkdir -p /registry
  sudo mkdir -p /etc/docker/certs.d/${registry_server}
  sudo cp /etc/registry/registry-cert.pem /etc/docker/certs.d/${registry_server}/ca.crt

  # Create authentication
  sudo mkdir /auth
  sudo docker run \
    --entrypoint htpasswd \
    registry:2 -Bbn ${registry_username} ${registry_password} | sudo tee /auth/htpasswd

  sudo docker run -d \
    --restart=always \
    --name registry \
    -v /etc/registry:/certs \
    -v /registry:/registry \
    -v /auth:/auth \
    -e "REGISTRY_AUTH=htpasswd" \
    -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:8500 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry-cert.pem \
    -e REGISTRY_HTTP_TLS_KEY=/certs/registry-key.pem  \
    -p 8500:8500 \
    registry:2

  # Retag images for private registry
  sudo docker images | grep -v REPOSITORY | grep -v ${registry_server} | awk '{print $1 ":" $2}' | xargs -n1 -I{} sudo docker tag {} ${registry_server}:8500/{}

  # ICP 3.1.0 archives also includes the architecture in image names which is not expected in private repos, also tag a non-arched version
  sudo docker images | grep ${registry_server}:8500 | grep "amd64" | awk '{gsub("-amd64", "") ; print $1 "-amd64:" $2 " " $1 ":" $2 }' | xargs -n2  sh -c 'sudo docker tag $1 $2' argv0

  # Push all images and tags to private docker registry
  sudo docker login --password ${registry_password} --username ${registry_username} ${registry_server}:8500
  while read image; do
    echo "Pushing ${image}"
    sudo docker push ${image} >> /tmp/imagepush.log
  done < <(sudo docker images | grep ${registry_server} | awk '{print $1 ":" $2}' | sort | uniq)


else
  # If we don't have an image locally we'll pull from docker registry
  if [[ -z $(docker images -q ${registry}${registry:+/}${org}/${repo}:${tag}) ]]; then
    # If this is a private registry we may need to log in
    if [[ ! -z "$username" ]]; then
      docker login -u ${username} -p ${password} ${registry}
    fi
    # ${registry}${registry:+/} adds <registry>/ only if registry is specified
    docker pull ${registry}${registry:+/}${org}/${repo}:${tag}
  fi
fi
