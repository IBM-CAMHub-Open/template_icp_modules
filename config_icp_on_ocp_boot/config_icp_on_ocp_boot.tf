resource "null_resource" "config_icp_boot_dependsOn" {
  provisioner "local-exec" {
    command = "echo The dependsOn output for ICP Boot is ${var.dependsOn}"
  }
}

resource "null_resource" "setup_installer" {
  depends_on = ["null_resource.config_icp_boot_dependsOn"]

  count = "1"

  connection {
    type        = "ssh"
    user        = "${var.vm_os_user}"
    password    = "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host        = "${var.ocp_installer}"
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
      "mkdir -p /opt/ibm-cloud-private-rhos-${var.icp_version}",
      "cd /opt/ibm-cloud-private-rhos-${var.icp_version}",
      "sudo docker run --rm -v $(pwd):/data:z -e LICENSE=accept --security-opt label:disable ibmcom/icp-inception-amd64:${var.icp_version}-rhel-ee cp -r cluster /data",
      "sudo cp /etc/origin/master/admin.kubeconfig cluster/kubeconfig"
    ]
  }

  provisioner "file" {
    source = "${path.module}/scripts/config_cluster.sh"
    destination = "/tmp/config_cluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sed -i 's/.*default_admin_password.*/default_admin_password: ${var.icp_admin_password}/g' /opt/ibm-cloud-private-rhos-${var.icp_version}/cluster/config.yaml",
      "sed -i -e '/default_admin_password/i default_admin_user: ${var.icp_admin_user}' /opt/ibm-cloud-private-rhos-${var.icp_version}/cluster/config.yaml",
      "sed -i -e '/default_admin_user/i cluster_name: ${var.icp_cluster_name}' /opt/ibm-cloud-private-rhos-${var.icp_version}/cluster/config.yaml",
      "chmod 755 /tmp/config_cluster.sh",
      "bash -c '/tmp/config_cluster.sh ${var.icp_master_host} ${var.icp_proxy_host} ${var.icp_management_host} ${var.ocp_master_host} ${var.ocp_vm_domain_name} ${var.icp_version} ${var.ocp_enable_glusterfs}'",
      "cd /opt/ibm-cloud-private-rhos-${var.icp_version}/cluster",
      "bash -c 'sudo docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z --security-opt label:disable ibmcom/icp-inception-amd64:${var.icp_version}-rhel-ee install-with-openshift | tee /tmp/install.log; test $${PIPESTATUS[0]} -eq 0'",
    ]
  }
}

resource "null_resource" "icp_install_finished" {
  depends_on = ["null_resource.setup_installer", "null_resource.config_icp_boot_dependsOn"]

  provisioner "local-exec" {
    command = "echo 'ICP has been installed on OCP.'"
  }
}
