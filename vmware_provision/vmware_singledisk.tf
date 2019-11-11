resource "vsphere_virtual_machine" "vm" {
  // count = "${var.count}"
  count = "${var.vm_disk2_enable == "false" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"

  name             = "${var.vm_name[count.index]}"
  folder           = "${var.vm_folder}"
  num_cpus         = "${var.vm_vcpu}"
  memory           = "${var.vm_memory}"
  resource_pool_id = "${data.vsphere_resource_pool.vsphere_resource_pool.id}"
  datastore_id     = "${data.vsphere_datastore.vsphere_datastore.id}"
  guest_id         = "${data.vsphere_virtual_machine.vm_template.guest_id}"
  scsi_type        = "${data.vsphere_virtual_machine.vm_template.scsi_type}"

  clone {
    template_uuid = "${data.vsphere_virtual_machine.vm_template.id}"
    timeout = "${var.vm_clone_timeout}"
    customize {
      linux_options {
        domain    = "${var.vm_domain}"
        host_name = "${var.vm_name[count.index]}"
      }

      network_interface {
        ipv4_address = "${var.vm_ipv4_address[count.index]}"
        ipv4_netmask = "${var.vm_ipv4_prefix_length}"
      }

      ipv4_gateway    = "${var.vm_ipv4_gateway}"
      dns_suffix_list = "${var.vm_dns_suffixes}"
      dns_server_list = "${var.vm_dns_servers}"
    }
  }

  network_interface {
    network_id   = "${data.vsphere_network.vm_network.id}"
    adapter_type = "${var.vm_adapter_type}"
  }

  disk {
    label          = "${var.vm_name[count.index]}.vmdk"
    size           = "${var.vm_disk1_size}"
    keep_on_remove = "${var.vm_disk1_keep_on_remove}"
    datastore_id   = "${data.vsphere_datastore.vsphere_datastore.id}"
  }

  // module "Setup_ssh_master" {
  //   source = "../../modules/ssh_keygen"
  //     os_admin_user = "${var.vm_os_user}"
  //     os_password = "${var.vm_os_password}"
  //     vm_private_ssh_key = "${var.vm_private_ssh_key}"
  //     vm_public_ssh_key = "${var.vm_public_ssh_key}"
  // }
  # Specify the connection
  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
    timeout  = "30m"
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

  provisioner "local-exec" {
    command = "echo \"${self.clone.0.customize.0.network_interface.0.ipv4_address}       ${self.name}.${var.vm_domain} ${self.name}\" >> /tmp/${var.random}/hosts"
  }
}

resource "null_resource" "add_ssh_key" {
  depends_on = ["vsphere_virtual_machine.vm"]
  count = "${var.vm_disk2_enable == "false" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"
  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
    timeout  = "30m"
    host = "${var.vm_ipv4_address[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"        
  }
  
  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'chmod +x VM_add_ssh_key.sh'",
      "bash -c './VM_add_ssh_key.sh  \"${var.vm_os_user}\" \"${var.vm_public_ssh_key}\" \"${var.vm_private_ssh_key}\">> VM_add_ssh_key.log 2>&1'",
    ]
  }
}

resource "vsphere_virtual_machine" "vm2disk" {
  // count = "${var.count}"
  count = "${var.vm_disk2_enable == "true" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"

  name             = "${var.vm_name[count.index]}"
  folder           = "${var.vm_folder}"
  num_cpus         = "${var.vm_vcpu}"
  memory           = "${var.vm_memory}"
  resource_pool_id = "${data.vsphere_resource_pool.vsphere_resource_pool.id}"
  datastore_id     = "${data.vsphere_datastore.vsphere_datastore.id}"
  guest_id         = "${data.vsphere_virtual_machine.vm_template.guest_id}"
  scsi_type        = "${data.vsphere_virtual_machine.vm_template.scsi_type}"

  clone {
    template_uuid = "${data.vsphere_virtual_machine.vm_template.id}"
    timeout = "${var.vm_clone_timeout}"
    
    customize {
      linux_options {
        domain    = "${var.vm_domain}"
        host_name = "${var.vm_name[count.index]}"
      }

      network_interface {
        ipv4_address = "${var.vm_ipv4_address[count.index]}"
        ipv4_netmask = "${var.vm_ipv4_prefix_length}"
      }

      ipv4_gateway    = "${var.vm_ipv4_gateway}"
      dns_suffix_list = "${var.vm_dns_suffixes}"
      dns_server_list = "${var.vm_dns_servers}"
    }
  }

  network_interface {
    network_id   = "${data.vsphere_network.vm_network.id}"
    adapter_type = "${var.vm_adapter_type}"
  }

  disk {
    label          = "${var.vm_name[count.index]}.vmdk"
    size           = "${var.vm_disk1_size}"
    keep_on_remove = "${var.vm_disk1_keep_on_remove}"

    // controller_type = "${var.vm_disk1_controller_type}"
    datastore_id = "${data.vsphere_datastore.vsphere_datastore.id}"
  }

  disk {
    label          = "${var.vm_name[count.index]}Disk2.vmdk"
    size           = "${var.vm_disk2_size}"
    keep_on_remove = "${var.vm_disk2_keep_on_remove}"
    datastore_id   = "${data.vsphere_datastore.vsphere_datastore.id}"
    unit_number    = 1
  }

  # Specify the connection
  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
    timeout  = "30m"
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

echo "Userid: $user_id"
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


  provisioner "local-exec" {
    command = "echo \"${self.clone.0.customize.0.network_interface.0.ipv4_address}       ${self.name}.${var.vm_domain} ${self.name}\" >> /tmp/${var.random}/hosts"
  }
}

resource "null_resource" "add_ssh_key_2disk" {
  count = "${var.vm_disk2_enable == "true" && var.enable_vm == "true" ? length(var.vm_ipv4_address) : 0}"
  depends_on = ["vsphere_virtual_machine.vm2disk"]
  
  # Specify the connection
  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
    timeout  = "30m"
    host = "${var.vm_ipv4_address[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"        
  }
  
  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'chmod +x VM_add_ssh_key.sh'",
      "bash -c 'echo \"${var.vm_os_user}\" \"${var.vm_public_ssh_key}\" \"${var.vm_private_ssh_key}\"'",
      "bash -c './VM_add_ssh_key.sh  \"${var.vm_os_user}\" \"${var.vm_public_ssh_key}\" \"${var.vm_private_ssh_key}\">> VM_add_ssh_key.log 2>&1'",
    ]
  }
}


resource "null_resource" "vm-create_done" {
  depends_on = ["vsphere_virtual_machine.vm", "vsphere_virtual_machine.vm2disk", "null_resource.add_ssh_key", "null_resource.add_ssh_key_2disk"]

  provisioner "local-exec" {
    command = "echo 'VM creates done for ${var.vm_name[count.index]}X.'"
  }
}

