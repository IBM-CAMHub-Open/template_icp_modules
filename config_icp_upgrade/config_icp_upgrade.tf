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
  provisioner "remote-exec" {
    inline = [
      "rm -rf /root/ibm-cloud-private-x86_64-${var.icp_version}",
      "mkdir -p /root/ibm-cloud-private-x86_64-${var.icp_version}"
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
  
  provisioner "file" {
    source = "${path.module}/scripts/download_icp.sh"
    destination = "/root/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/rollback_icp.sh"
    destination = "/root/ibm-cloud-private-x86_64-${var.icp_version}/rollback_icp.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/upgrade_icp.sh"
    destination = "/root/ibm-cloud-private-x86_64-${var.icp_version}/upgrade_icp.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod 755 /root/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh",
      "echo /root/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password}",
      "bash -c '/root/ibm-cloud-private-x86_64-${var.icp_version}/download_icp.sh -i ${var.icp_url} -v ${var.icp_version} -u ${var.download_user} -p ${var.download_user_password}'"
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
      "cp -r ${var.cluster_location}/cfc-certs /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "cp -r ${var.cluster_location}/cfc-keys /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "cp -r ${var.cluster_location}/cfc-components /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "cp ${var.cluster_location}/hosts /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "cp ${var.cluster_location}/ssh_key /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",

      "sed -i -e 's/\"vulnerability-advisor\"/\"va\", \"vulnerability-advisor\"/g' /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"version: ${var.icp_version}\" >> /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -e '1,/^version: \\b/d' ${var.cluster_location}/config.yaml >> /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "grep \"^ingress_controller:\" -q ${var.cluster_location}/config.yaml && printf \"nginx-ingress:\ningress:\nconfig:\n\" >> /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -n '/^disable-access-log:/p' ${var.cluster_location}/config.yaml >> /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",

      "cd /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "chmod 755 /root/ibm-cloud-private-x86_64-${var.icp_version}/upgrade_icp.sh",
      "echo /root/ibm-cloud-private-x86_64-${var.icp_version}/upgrade_icp.sh ${var.icp_version}",
      "/root/ibm-cloud-private-x86_64-${var.icp_version}/upgrade_icp.sh ${var.icp_version}"
    ]
  }

  provisioner "remote-exec" {
    when                  = "destroy"
    inline                = [
      "chmod 755 /root/ibm-cloud-private-x86_64-${var.icp_version}/rollback_icp.sh",
      "cd /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "echo /root/ibm-cloud-private-x86_64-${var.icp_version}/rollback_icp.sh ${var.icp_version} ${var.icp_cluster_name} ${var.kube_apiserver_secure_port} ${var.master_node_ip} ${var.cluster_vip}",
      "/root/ibm-cloud-private-x86_64-${var.icp_version}/rollback_icp.sh ${var.icp_version} ${var.icp_cluster_name} ${var.kube_apiserver_secure_port} ${var.master_node_ip} ${var.cluster_vip}"
    ]
  }
}

resource "null_resource" "icp_upgrade_finished" {
  depends_on = ["null_resource.load_icp_images","null_resource.config_icp_upgrade_dependsOn","null_resource.mkdir-boot-node","null_resource.icp_upgrade"]
  provisioner "local-exec" {
    command = "echo 'Upgraded to new ICP version'"
  }
}