resource "null_resource" "config_icp_upgrade_dependsOn" {
  provisioner "local-exec" {
	  command = "echo The dependsOn output for Config ICP Upgrade is ${var.dependsOn}"
  }
}

resource "null_resource" "mkdir-boot-node" {
  depends_on = ["null_resource.config_icp_upgrade_dependsOn"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.boot_node_ip}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"  
  }

  provisioner "file" {
    source = "${path.module}/scripts/download_icp.sh"
    destination = "/tmp/download_icp.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/rollback_icp.sh"
    destination = "/tmp/rollback_icp.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/upgrade_icp.sh"
    destination = "/tmp/upgrade_icp.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "[ ${var.icp_version} != \"2.1.0.3-fp1\" ] && rm -rf ~/ibm-cloud-private-x86_64-${var.icp_version} || :",
      "[ ${var.icp_version} != \"2.1.0.3-fp1\" ] && mkdir -p ~/ibm-cloud-private-x86_64-${var.icp_version} || :"
    ]
  }
}

resource "null_resource" "load_icp_images" {
  depends_on = ["null_resource.mkdir-boot-node"]
  #count = "${var.enable_bluemix_install == "false" ? length(var.vm_ipv4_address_list) : 0}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.boot_node_ip}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"  
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 /tmp/download_icp.sh",
      "echo /tmp/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}",
      "bash -c '/tmp/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password} -o ${var.vm_os_user}'"
    ]
  }
}

resource "null_resource" "icp_upgrade" {
  depends_on = ["null_resource.load_icp_images","null_resource.mkdir-boot-node"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host = "${var.boot_node_ip}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"  
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "[ ${var.icp_version} != \"2.1.0.3-fp1\" ] && cd ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster || cd ~/ibm-cloud-private-x86_64-2.1.0.3/cluster",
      "chmod 755 /tmp/upgrade_icp.sh",
      "echo /tmp/upgrade_icp.sh ${var.icp_version} ${var.cluster_location}",
      "/tmp/upgrade_icp.sh ${var.icp_version} ${var.cluster_location}"
    ]
  }

  provisioner "remote-exec" {
    when                  = "destroy"
    inline                = [
      "set -e",
      "[ ${var.icp_version} != \"2.1.0.3-fp1\" ] && cd ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster || cd ~/ibm-cloud-private-x86_64-2.1.0.3/cluster",
      "chmod 755 /tmp/rollback_icp.sh",
      "echo /tmp/rollback_icp.sh ${var.icp_version} ${var.icp_cluster_name} ${var.kube_apiserver_secure_port} ${var.master_node_ip}",
      "/tmp/rollback_icp.sh ${var.icp_version} ${var.icp_cluster_name} ${var.kube_apiserver_secure_port} ${var.master_node_ip}"
    ]
  }
}

resource "null_resource" "icp_upgrade_finished" {
  depends_on = ["null_resource.load_icp_images","null_resource.config_icp_upgrade_dependsOn","null_resource.mkdir-boot-node","null_resource.icp_upgrade"]
  provisioner "local-exec" {
    command = "echo 'Upgraded to new ICP version'"
  }
}