#!/bin/bash

function delnode()
{
	deliphost=$1
	failed="true"
	#Try 5 times. kubectl command fails to delete nodes sometimes due to connectivity issue.
	for count in {1..5}
	do
  		err=$(mktemp)
  		delcmd=$($kubectl delete node ${deliphost} 2>$err)
  		delcmderr=$(< $err)	    	
	    rm $err
    	if [[ ! -z $delcmderr ]]
    	then
  	    	echo Error is $delcmderr
  	    	echo "Retry delete nodes $count out of 5"
		else
        	echo "Delete nodes output is $delcmd"
        	printf "\033[32m[*] Node ${deliphost} has been removed successfully \033[0m\n"
        	failed="false"
        	break
    	fi
    done	
    if [[ "$failed" == "true" ]]; then
    	printf "\033[32m[*] Node ${deliphost} failed to remove\033[0m\n"
	fi
}

echo "sleep 300s to allow destroyed resources to show up"
sleep 300

source /tmp/icp-bootmaster-scripts/functions.sh

ICPDIR=/opt/ibm/cluster
NEWLIST=/tmp/workerlist.txt
OLDLIST=${ICPDIR}/workerlist.txt

# First parse the hostgroup json
python /tmp/icp-bootmaster-scripts/parse-hostgroups.py

CLUSTER_IPS_LIST=/tmp/cluster-ips.txt

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}


# Compare new and old list of workers
declare -a newlist
IFS=', ' read -r -a newlist <<< $(cat ${NEWLIST})

declare -a oldlist
IFS=', ' read -r -a oldlist <<< $(cat ${OLDLIST})

declare -a clusterips
IFS=', ' read -r -a clusterips <<< $(cat ${CLUSTER_IPS_LIST})

declare -a added
declare -a removed

# As a precausion, if either list is empty, something might have gone wrong and we should exit in case we delete all nodes in error
# When using hostgroups this is expected behaviour, so need to exit 0 rather than cause error.
if [ ${#oldlist[@]} -eq 0 ]; then
  echo "Couldn't find any entries in old list of workers. Exiting'"
  exit 0
fi
if [ ${#newlist[@]} -eq 0 ]; then
  echo "Couldn't find any entries in the new list of workers. Exiting'"
  exit 0
fi

#Filter duplicate entries.
declare -a unqoldlist
for oip in "${oldlist[@]}"; do	
	if [ ${#unqoldlist[@]} -eq 0 ]; then	    
    	unqoldlist+=(${oip})
	else
        found="false"
        for unoip in "${unqoldlist[@]}"; do
            if [[ "$unoip" == "$oip" ]]; then
                found="true"
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            unqoldlist+=(${oip})
        fi			
	fi	
done

# Cycle through old ips to find removed workers
for oip in "${unqoldlist[@]}"; do
  echo "process old list ip ${oip}"
  if  ping -c 1 -W 1 "${oip}"; then 

	  if [[ "${newlist[@]}" =~ "${oip}" ]]; then
	    echo "${oip} is still here"
	  fi

	  if [[ ! " ${newlist[@]} " =~ " ${oip} " ]]; then
	    # whatever you want to do when arr doesn't contain value
	    echo "remove ip ${oip}"
	    removed+=(${oip})
	  fi
  else
 	echo "${oip} cannot be accessed, remove it"
 	removed+=(${oip})
  fi 	

done

# Cycle through new ips to find added workers
for nip in "${newlist[@]}"; do
  echo "process NEW list ip ${nip}"
  if [[ "${unqoldlist[@]}" =~ "${nip}" ]]; then
    echo "${nip} is still here, new list"
  fi

  if [[ ! " ${unqoldlist[@]} " =~ " ${nip} " ]]; then
    # whatever you want to do when arr doesn't contain value
    
    END=5
    x=$END
	while [ $x -gt 0 ]; 
	do 
		x=$(($x-1))	
    	pingcmd=$(ping -c 1 -W 1 "${nip}")
	    RC=$?
	    if [ $RC -eq 0 ]; then
	      break
	    else
	      echo "cannot ping ${nip} sleep 60s"
	      sleep 60  
	    fi
	    
    done
    
    added+=(${nip})
  fi
done


iam=$(whoami)
myip=`ip route get 10.0.0.11 | awk 'NR==1 {print $NF}'`
echo "myip=$myip"

if ! [ -f ~/.ssh/icp_rsa.pub ]; then
	ssh-keygen -y -f ${ICPDIR}/ssh_key > ~/.ssh/icp_rsa.pub 
fi

if [[ -n ${removed} ]]
then
  echo "removing workers: ${removed[@]}"


  ### Setup kubectl


	cluster_ca_name=$(awk '/cluster_CA_domain/ {print $2}' ${ICPDIR}/config.yaml)
	cluster_lb_address=$(awk '/cluster_lb_address/ {print $2}' ${ICPDIR}/config.yaml)
	cluster_name=$(awk '/cluster_name/ {print $2}' ${ICPDIR}/config.yaml)

	if ! which kubectl; then
		echo "install kubectl"
		
		# Get the architecture
		systemArch=$(arch)
		if [ "${systemArch}" == "x86_64" ]; then systemArch='amd64'; fi
		# Set arch in dev.yaml
		if [ "${systemArch}" == 'ppc64le' ]; then
			if [ -f dev.yaml ]; then
				if $(grep -q "^arch:*" dev.yaml); then
					echo "arch line found"
					sed -i -e "/arch:*/c\arch:\ ${systemArch}" dev.yaml
				else
					echo 'arch line not found'
					sed -i -e '$a'"arch:\ ${systemArch}" dev.yaml
				fi
			fi
		fi
		
		curl -kLo kubectl-linux-${systemArch} https://${cluster_ca_name}:8443/api/cli/kubectl-linux-amd64	
		chmod +x ./kubectl-linux-${systemArch}	
		sudo mv ./kubectl-linux-${systemArch} /usr/local/bin/kubectl
	fi

  # use kubectl from container
  kubectl="sudo docker run -e LICENSE=accept --net=host -v ${ICPDIR}:${ICPDIR} -v /root:/root ${registry}${registry:+/}${org}/${repo}:${tag} kubectl"

  $kubectl config set-cluster cfc-cluster --server=https://localhost:8001 --insecure-skip-tls-verify=true
  $kubectl config set-context kubectl --cluster=cfc-cluster
  $kubectl config set-credentials user --client-certificate=${ICPDIR}/cfc-certs/kubernetes/kubecfg.crt --client-key=${ICPDIR}/cfc-certs/kubernetes/kubecfg.key
  $kubectl config set-context kubectl --user=user
  $kubectl config use-context kubectl
  #$kubectl get nodes
  err=$(mktemp)
  nodescmd=$($kubectl get nodes 2>$err)
  nodescmderr=$(< $err)
  rm $err
  echo "Get nodes output is $nodescmd"
  echo "Get nodes error is $nodescmderr"
  #If kubectl is rejected on localhost use ${cluster_ca_name} 
  if [[ ! -z $nodescmderr ]]
  then
  	echo "Use cluster_ca_name for kube configuration instead of localhost"
	$kubectl config set-cluster cfc-cluster --server=https://${cluster_ca_name}:8001 --insecure-skip-tls-verify=true
  	$kubectl config set-context kubectl --cluster=cfc-cluster
  	$kubectl config set-credentials user --client-certificate=${ICPDIR}/cfc-certs/kubernetes/kubecfg.crt --client-key=${ICPDIR}/cfc-certs/kubernetes/kubecfg.key
  	$kubectl config set-context kubectl --user=user
  	$kubectl config use-context kubectl  
  	#Try 5 times. kubectl command fails to get nodes sometimes due to connectivity issue.
	for count in {1..5}
	do
        #$kubectl get nodes
		err=$(mktemp)
  		nodescmd=$($kubectl get nodes 2>$err)
  		nodescmderr=$(< $err)
  		rm $err
        if [[ ! -z $nodescmderr ]]
        then
      	    echo Error is $nodescmderr
            echo "Retry get nodes $count out of 5"
		else
            echo "Get nodes output is $nodescmd"
            break
        fi
	done  		
  fi

  list=$(IFS=, ; echo "${removed[*]}")

  for ip in "${removed[@]}"; do
  
	  echo "${ip} remove node"
	  if [[ "$nodescmd" =~ "${ip}" ]]; then
		delnode ${ip}
	  else
        printf "\033[31m[ERROR] Node ${ip} not found, try to find the node by host\033[0m\n"
      
		for oip in "${clusterips[@]}"; do
			  echo "Process  ${oip}"    
		      if [[ ${oip} != ${ip} ]] && [[ ${myip} != ${oip} ]] ; then	
					if ping -c 1 -W 1 "${oip}"; then
					  echo "${oip} is alive, find host for ${ip} from its /etc/hosts"
					  iphostname=$(ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${oip} "awk '\$1==\"${ip}\" {print \$2}' /etc/hosts")  
			          echo "iphostname=$iphostname"
						if ! [ -z "${iphostname}" ]; then
						  delnode ${iphostname}
 					      break 
						fi	
					fi	
		      fi
		 done     						          
      fi

    #remove node from new list
	sudo sed -i -e "s/${ip},//g"  ${NEWLIST} 
	sudo sed -i -e "s/,${ip}//g"  ${NEWLIST} 
	   
    sudo sed -i "/^${ip} /d" /etc/hosts
    sudo sed -i "/^${ip} /d" ${ICPDIR}/hosts
    
	for oip in "${clusterips[@]}"; do
	  echo "Process  ${oip}"
      if [[ ${oip} != ${ip} ]] && [[ ${myip} != ${ip} ]] ; then	
			if ping -c 1 -W 1 "${oip}"; then
			  echo "${oip} is alive, remove ${ip} from its /etc/hosts"
			  ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${oip} "sudo sed -i '/^'\"${ip} \"' /d' /etc/hosts"

			else
			  echo "${oip} cannot be accessed, will not remove ${ip} from its /etc/hosts"
			fi
            
	   fi       
	done
    
  done
	# Backup the origin list and replace
	mv ${OLDLIST} ${OLDLIST}-$(date +%Y%m%dT%H%M%S)
	mv ${NEWLIST} ${OLDLIST} 
  
fi

if [[ -n ${added} ]]
then
  echo "Adding: ${added[@]}"
    
  # Collect node names

  # Update /etc/hosts
  for node in "${added[@]}" ; do

	if ping -c 1 -W 1 "${node}"; then
	    echo "${node} is alive, process it"
		ssh-keyscan ${node} | tee -a ~/.ssh/known_hosts
			  
		cat ~/.ssh/icp_rsa.pub | ssh $iam@${node} "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >>  ~/.ssh/authorized_keys"  
	    
	    nodename=$(ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${node} hostname)
	    RC=$?
	    if ! [ $RC -eq 0 ]
	    then
	      echo " Failed to get the hostname for ${node}, exit now ." 
	      exit 1
	    fi 
	    
		ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key $iam@${node} mkdir -p /tmp/icp-common-scripts
		scp -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key /tmp/icp-common-scripts/* $iam@${node}:/tmp/icp-common-scripts/
		ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key $iam@${node} /tmp/icp-common-scripts/prereqs.sh
		ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key $iam@${node} /tmp/icp-common-scripts/version-specific.sh ${1}
		ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key $iam@${node} /tmp/icp-common-scripts/docker-user.sh
		   
	    printf "%s     %s\n" "$node" "$nodename" | cat - /etc/hosts | sudo sponge /etc/hosts
	    printf "%s     %s\n" "$node" "$nodename" | ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${node} 'cat - /etc/hosts | sudo sponge /etc/hosts'	  
	else
	    echo "${node} cannot be accessed"
	    exit 1
	fi

  done

  list=$(IFS=, ; echo "${added[*]}")
  echo "running sudo docker run -e LICENSE=accept --net=host -v ${ICPDIR}:/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} worker -l ${list}"
  if sudo docker run -e LICENSE=accept --net=host -v "${ICPDIR}":/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} worker -l ${list} ; then

	  for node in "${added[@]}" ; do
	  
			# Cycle through all ips and add the new one to the /etc/hosts
			for oip in "${clusterips[@]}"; do
			  echo "Process  ${oip}"
		      if [[ ${oip} != ${node} ]]; then	
				if ping -c 1 -W 1 "${oip}"; then
		      
				    oipnodename=$(ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${oip} hostname)
				    RC=$?
				    if ! [ $RC -eq 0 ]
				    then
				      echo " Failed to get the hostname for ${oip} will not add this ip to new node /etc/hosts"
				    else
				      echo "Will add ${oip} $oipnodename to new node ${node} /etc/hosts"
					  printf "%s     %s\n" "${oip}" "$oipnodename" | ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${node} 'cat - /etc/hosts | sudo sponge /etc/hosts'
			
				      echo "Will add ${node} $nodename to ${oip} /etc/hosts"
					  printf "%s     %s\n" "${node}" "$nodename" | ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${oip} 'cat - /etc/hosts | sudo sponge /etc/hosts'
			       
			        fi
			     fi   
			   fi       
			done
	    done 
	    printf "\033[32m[*] Add node ${list} Succeeded \033[0m\n"
		# Backup the origin list and replace
		mv ${OLDLIST} ${OLDLIST}-$(date +%Y%m%dT%H%M%S)
		mv ${NEWLIST} ${OLDLIST} 

  else
        printf "\033[31m[ERROR] Add node ${list} Failed\033[0m\n"
        exit 1  
  fi
	  
fi
