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

  provisioner "file" {
    source      = "${path.module}/scripts/config_glusterfs.sh"
    destination = "/tmp/config_glusterfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /tmp/add_public_key.sh",
      "/tmp/add_public_key.sh ${join(",", var.new_node_IPs)} ${var.vm_os_user} ${var.vm_os_password}",
      "cp /root/.ssh/id_rsa /root/ibm-cloud-private-x86_64-${var.icp_version}/cluster/ssh_key",
      "cd ${var.cluster_location}",
      "docker run -e LICENSE=accept --net=host -v $(pwd):/installer/cluster ibmcom/icp-inception:${var.icp_version}-ee ${var.node_type} -l ${join(",", var.new_node_IPs)} && printf \"\\033[32m[*] Add Node Succeeded \\033[0m\\n\" || (printf \"\\033[31m[ERROR] Add Node Failed\\033[0m\\n\" && exit 1)",
      "chmod 755 /tmp/config_glusterfs.sh",
      "/tmp/config_glusterfs.sh ${var.enable_glusterFS} ${var.node_type} /root/glusterfs.txt ${var.cluster_location} ${var.icp_version}",
    ]
  }

  provisioner "remote-exec" {
    when                  = "destroy"
    inline                = [
      "cd ${var.cluster_location}",
      "docker run -e LICENSE=accept --net=host -v $(pwd):/installer/cluster ibmcom/icp-inception:${var.icp_version}-ee uninstall -l ${join(",", var.new_node_IPs)} && printf \"\\033[32m[*] Remove Node Succeeded \\033[0m\\n\" || (printf \"\\033[31m[ERROR] Remove Node Failed\\033[0m\\n\" && exit 1)",
    ]
  }
}
