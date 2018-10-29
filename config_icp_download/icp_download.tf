resource "null_resource" "config_icp_download_dependsOn" {
  provisioner "local-exec" {
# Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
	  command = "echo The dependsOn output for Config ICP Download is ${var.dependsOn}"
  }
}

resource "null_resource" "mkdir-boot-node" {
  depends_on = ["null_resource.config_icp_download_dependsOn"]
  count = "${length(var.vm_ipv4_address_list)}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.vm_ipv4_address_list[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
    provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/ibm-cloud-private-x86_64-${var.icp_version}"
    ]
  }
}


resource "null_resource" "install_docker" {
  depends_on = ["null_resource.mkdir-boot-node"]

  count = "${length(var.vm_ipv4_address_list)}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.vm_ipv4_address_list[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  provisioner "file" {
    source = "${path.module}/scripts/docker_install.sh"
    destination = "~/ibm-cloud-private-x86_64-${var.icp_version}/docker_install.sh"
  }
    
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 ~/ibm-cloud-private-x86_64-${var.icp_version}/docker_install.sh",
      "echo ~/ibm-cloud-private-x86_64-${var.icp_version}/docker_install.sh -d ${var.docker_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}",
      "bash -c '~/ibm-cloud-private-x86_64-${var.icp_version}/docker_install.sh -d ${var.docker_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}'"
    ]
  }
}

resource "null_resource" "load_icp_images" {
  depends_on = ["null_resource.mkdir-boot-node","null_resource.install_docker"]

  count = "${var.enable_bluemix_install == "false" ? length(var.vm_ipv4_address_list) : 0}"
#  count = "${length(var.vm_ipv4_address_list)}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.vm_ipv4_address_list[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/download_icp.sh"
    destination = "~/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 ~/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh",
      "echo ~/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}",
      "bash -c '~/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}'"
      # "tar -xf  ibm-cloud-private-x86_64-${var.ICP_Version}.tar.gz -O | sudo docker load",
      # export DOCKER_REPO=`sudo docker images |grep inception |grep ${var.icp_version} |awk '{print $1}'`.
      # "sudo docker run -v $(pwd):/data -e LICENSE=accept $DOCKER_REPO:${var.ICP_Version}-ee cp -r cluster /data",
      # "mkdir -p cluster/images; mv ibm-cloud-private-x86_64-${var.ICP_Version}.tar.gz cluster/images/"
    ]
  }
}

resource "null_resource" "docker_install_finished" {
  depends_on = ["null_resource.load_icp_images","null_resource.config_icp_download_dependsOn","null_resource.install_docker","null_resource.mkdir-boot-node"]
  provisioner "local-exec" {
    command = "echo 'Docker and ICP Images loaded, has been installed on Nodes'"
  }
}
