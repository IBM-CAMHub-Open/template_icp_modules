#!/bin/bash

if [ $1 != "root" ]; then
	#Comment ansible settings in case they were set before
    sed -i 's/ansible_user/#ansible_user/g' ~/ibm-cloud-private-x86_64-$2/cluster/config.yaml
    sed -i 's/ansible_become/#ansible_become/g' ~/ibm-cloud-private-x86_64-$2/cluster/config.yaml
    echo "ansible_user: $1" >> ~/ibm-cloud-private-x86_64-$2/cluster/config.yaml
    echo "ansible_become: true" >> ~/ibm-cloud-private-x86_64-$2/cluster/config.yaml
fi