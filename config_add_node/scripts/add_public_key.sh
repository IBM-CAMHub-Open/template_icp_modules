#!/bin/bash
sudo apt-get install sshpass
sudo chown $2 ~/.ssh/known_hosts
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
ips=$(echo $1 | sed 's/[][]//g') && IFS=', '
for ip in $ips; do
    echo "add key for $ip"
    ssh-keygen -R $ip
    ssh-keyscan -H $ip >> ~/.ssh/known_hosts
    sshpass -p $3 ssh-copy-id -i ~/.ssh/id_rsa.pub $2@$ip 
done

