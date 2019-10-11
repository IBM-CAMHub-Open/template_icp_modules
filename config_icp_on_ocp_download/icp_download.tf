resource "null_resource" "config_icp_download_dependsOn" {
  provisioner "local-exec" {
# Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
	  command = "echo The dependsOn output for Config ICP Download is ${var.dependsOn}"
  }
}

resource "null_resource" "mkdir-boot-node" {
  depends_on = ["null_resource.config_icp_download_dependsOn"]
  count = "1"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.ocp_installer}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
    provisioner "remote-exec" {
    inline = [
      "sudo kubectl label nodes ${var.ocp_installer} node-role.kubernetes.io/compute=true",
      "sudo sysctl -w vm.max_map_count=262144",
      "echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf",
      "mkdir -p /opt/ibm-cloud-private-rhos-${var.icp_version}"
    ]
  }
}

resource "null_resource" "load_icp_images" {
  depends_on = ["null_resource.mkdir-boot-node"]

  count = "1"

  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.ocp_installer}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/download_icp.sh"
    destination = "/opt/ibm-cloud-private-rhos-${var.icp_version}/download_icp.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 /opt/ibm-cloud-private-rhos-${var.icp_version}/download_icp.sh",
      "echo /opt/ibm-cloud-private-rhos-${var.icp_version}/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}",
      "bash -c '/opt/ibm-cloud-private-rhos-${var.icp_version}/download_icp.sh -i \"${var.icp_url}\" -v \"${var.icp_version}\" -u \"${var.download_user}\" -p \"${var.download_user_password}\" -o \"${var.vm_os_user}\"'"
    ]
  }
}

resource "null_resource" "docker_install_finished" {
  depends_on = ["null_resource.load_icp_images","null_resource.config_icp_download_dependsOn","null_resource.mkdir-boot-node"]
  provisioner "local-exec" {
    command = "echo 'ICP Images loaded, has been installed on Nodes'"
  }
}
