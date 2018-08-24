#!/bin/bash
apt-get install sshpass
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
ips=$(echo $1 | sed 's/[][]//g') && IFS=', ' read -r -a ips <<< "$ips"
for ip in ${ips[@]}; do
    ssh-keygen -R $ip
    ssh-keyscan -H $ip >> ~/.ssh/known_hosts
    sshpass -p $3 ssh-copy-id -i ~/.ssh/id_rsa.pub $2@$ip 
done

