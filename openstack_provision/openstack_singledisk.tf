##################################################################################################
#                                    Single Disk VM 
##################################################################################################
resource "openstack_compute_instance_v2" "vm" {
  count = "${var.vm_disk2_enable == "false" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"

  name            = "${var.vm_name[count.index]}"
  image_id        = "${var.vm_image_id}"
  flavor_id       = "${var.vm_flavor_id}"
  security_groups = "${var.vm_security_groups}"
  user_data       = "#cloud-config\nhostname: ${var.vm_name[count.index]}\nfqdn: ${var.vm_name[count.index]}.${var.vm_domain}\nmanage_etc_hosts: true"

  network {
    name = "${var.vm_public_ip_pool}"
    fixed_ip_v4 = "${var.vm_ipv4_address[count.index]}"
  }

  block_device {
    uuid                  = "${var.vm_image_id}"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = "${var.vm_disk1_size}"
    boot_index            = 1
    delete_on_termination = "${var.vm_disk1_delete_on_termination}"
  }

  provisioner "local-exec" {
    command = "echo \"${self.network.0.fixed_ip_v4}       ${var.vm_name[count.index]}.${var.vm_domain} ${var.vm_name[count.index]}\" >> /tmp/${var.random}/hosts"
  }
}

resource "null_resource" "vm_provision" {
  count = "${var.vm_disk2_enable == "false" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"
  depends_on = ["openstack_compute_instance_v2.vm"]
  connection {
    user                = "${var.vm_os_user}"
    password            = "${var.vm_os_password}"
    host                = "${var.vm_ipv4_address[count.index]}"
    timeout             = "1200s"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}" 
  }

  provisioner "file" {
    destination = "VM_add_ssh_key.sh"

    content = <<EOF
# =================================================================
# Licensed Materials - Property of IBM
# 5737-E67
# @ Copyright IBM Corporation 2016, 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
# =================================================================
#!/bin/bash

if (( $# != 3 )); then
echo "usage: arg 1 is user, arg 2 is public key, arg3 is Private Key"
exit -1
fi

userid="$1"
ssh_key="$2"
private_ssh_key="$3"


echo "Userid: $userid"

echo "ssh_key: $ssh_key"
echo "private_ssh_key: $private_ssh_key"


user_home=$(eval echo "~$userid")
user_auth_key_file=$user_home/.ssh/authorized_keys
user_auth_key_file_private=$user_home/.ssh/id_rsa
user_auth_key_file_private_temp=$user_home/.ssh/id_rsa_temp
echo "$user_auth_key_file"
if ! [ -f $user_auth_key_file ]; then
echo "$user_auth_key_file does not exist on this system, creating."
mkdir -p $user_home/.ssh
chmod 700 $user_home/.ssh
touch $user_home/.ssh/authorized_keys
chmod 600 $user_home/.ssh/authorized_keys
else
echo "user_home : $user_home"
fi

echo "$user_auth_key_file"
echo "$ssh_key" >> "$user_auth_key_file"
if [ $? -ne 0 ]; then
echo "failed to add to $user_auth_key_file"
exit -1
else
echo "updated $user_auth_key_file"
fi

# echo $private_ssh_key  >> $user_auth_key_file_private_temp
# decrypt=`cat $user_auth_key_file_private_temp | base64 --decode`
# echo "$decrypt" >> "$user_auth_key_file_private"

echo "$private_ssh_key"  >> "$user_auth_key_file_private"
chmod 600 $user_auth_key_file_private
if [ $? -ne 0 ]; then
echo "failed to add to $user_auth_key_file_private"
exit -1
else
echo "updated $user_auth_key_file_private"
fi
rm -rf $user_auth_key_file_private_temp

EOF
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'hostnamectl set-hostname \"${var.vm_name[count.index]}\"'",
      "bash -c 'chmod +x VM_add_ssh_key.sh'",
      "bash -c './VM_add_ssh_key.sh  \"${var.vm_os_user}\" \"${var.vm_public_ssh_key}\" \"${var.vm_private_ssh_key}\">> VM_add_ssh_key.log 2>&1'",
    ]
  }
}

##################################################################################################
#                                    Two Disk VM 
##################################################################################################
resource "openstack_compute_instance_v2" "vm2disk" {
  count = "${var.vm_disk2_enable == "true" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"

  name            = "${var.vm_name[count.index]}"
  image_id        = "${var.vm_image_id}"
  flavor_id       = "${var.vm_flavor_id}"
  security_groups = "${var.vm_security_groups}"
  user_data       = "#cloud-config\nhostname: ${var.vm_name[count.index]}\nfqdn: ${var.vm_name[count.index]}.${var.vm_domain}\nmanage_etc_hosts: true"

  network {
    name        = "${var.vm_public_ip_pool}"
    fixed_ip_v4 = "${var.vm_ipv4_address[count.index]}"
  }

  block_device {
    uuid                  = "${var.vm_image_id}"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = "${var.vm_disk1_size}"
    boot_index            = 1
    delete_on_termination = "${var.vm_disk1_delete_on_termination}"
  }

  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = "${var.vm_disk2_size}"
    boot_index            = 2
    delete_on_termination = "${var.vm_disk2_delete_on_termination}"
  }

  provisioner "local-exec" {
    command = "echo \"${self.network.0.fixed_ip_v4}       ${var.vm_name[count.index]}.${var.vm_domain} ${var.vm_name[count.index]}\" >> /tmp/${var.random}/hosts"
  }
}

resource "null_resource" "vm2disk_provision" {
  count = "${var.vm_disk2_enable == "true" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"
  depends_on = ["openstack_compute_instance_v2.vm2disk"]
  connection {
    user                = "${var.vm_os_user}"
    password            = "${var.vm_os_password}"
    host                = "${var.vm_ipv4_address[count.index]}"
    timeout             = "1200s"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}" 
  }

  provisioner "file" {
    destination = "VM_add_ssh_key.sh"

    content = <<EOF
# =================================================================
# Licensed Materials - Property of IBM
# 5737-E67
# @ Copyright IBM Corporation 2016, 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
# =================================================================
#!/bin/bash

if (( $# != 3 )); then
echo "usage: arg 1 is user, arg 2 is public key, arg3 is Private Key"
exit -1
fi

userid="$1"
ssh_key="$2"
private_ssh_key="$3"


echo "Userid: $userid"

echo "ssh_key: $ssh_key"
echo "private_ssh_key: $private_ssh_key"


user_home=$(eval echo "~$userid")
user_auth_key_file=$user_home/.ssh/authorized_keys
user_auth_key_file_private=$user_home/.ssh/id_rsa
user_auth_key_file_private_temp=$user_home/.ssh/id_rsa_temp
echo "$user_auth_key_file"
if ! [ -f $user_auth_key_file ]; then
echo "$user_auth_key_file does not exist on this system, creating."
mkdir $user_home/.ssh
chmod 700 $user_home/.ssh
touch $user_home/.ssh/authorized_keys
chmod 600 $user_home/.ssh/authorized_keys
else
echo "user_home : $user_home"
fi

echo "$user_auth_key_file"
echo "$ssh_key" >> "$user_auth_key_file"
if [ $? -ne 0 ]; then
echo "failed to add to $user_auth_key_file"
exit -1
else
echo "updated $user_auth_key_file"
fi

# echo $private_ssh_key  >> $user_auth_key_file_private_temp
# decrypt=`cat $user_auth_key_file_private_temp | base64 --decode`
# echo "$decrypt" >> "$user_auth_key_file_private"

echo "$private_ssh_key"  >> "$user_auth_key_file_private"
chmod 600 $user_auth_key_file_private
if [ $? -ne 0 ]; then
echo "failed to add to $user_auth_key_file_private"
exit -1
else
echo "updated $user_auth_key_file_private"
fi
rm -rf $user_auth_key_file_private_temp

EOF
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'hostnamectl set-hostname \"${var.vm_name[count.index]}\"'",
      "bash -c 'chmod +x VM_add_ssh_key.sh'",
      "bash -c './VM_add_ssh_key.sh  \"${var.vm_os_user}\" \"${var.vm_public_ssh_key}\" \"${var.vm_private_ssh_key}\">> VM_add_ssh_key.log 2>&1'",
    ]
  }
}

resource "null_resource" "vm_create_done" {
  depends_on = ["null_resource.vm_provision", "null_resource.vm2disk_provision"]

  provisioner "local-exec" {
    command = "echo 'VM creates done for ${var.vm_name[count.index]}X.'"
  }
}