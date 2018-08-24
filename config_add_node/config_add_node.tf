resource "null_resource" "add_worker_node_dependsOn" {
  provisioner "local-exec" {
    command = "echo The dependsOn output for ICP Boot is ${var.dependsOn}"
  }
}

### to add node###
resource "null_resource" "addNode" {
  depends_on = ["null_resource.add_worker_node_dependsOn"]

  connection {
    host = "${var.boot_node_IP}"
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
    private_key = "${var.private_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"            
  }

  provisioner "file" {
    source      = "${path.module}/scripts/add_public_key.sh"
    destination = "/tmp/add_public_key.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /tmp/add_public_key.sh",
      "/tmp/add_public_key.sh ${join(",", var.new_node_IPs)} ${var.vm_os_user} ${var.vm_os_password}",
      "cp /root/.ssh/id_rsa /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/ssh_key",
      "cd ${var.cluster_location}",
      "docker run -e LICENSE=accept --net=host -v $(pwd):/installer/cluster ibmcom/icp-inception:${var.icp_version}-ee ${var.node_type} -l ${join(",", var.new_node_IPs)}",
    ]
  }

  provisioner "remote-exec" {
    when                  = "destroy"
    inline                = [
      "cd ${var.cluster_location}",
      "docker run -e LICENSE=accept --net=host -v $(pwd):/installer/cluster ibmcom/icp-inception:${var.icp_version}-ee uninstall -l ${join(",", var.new_node_IPs)}",
    ]
  }
}
