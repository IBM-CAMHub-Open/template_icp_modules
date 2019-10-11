###
# Gather output for mcm 3.2
###
resource "null_resource" "icp_install_finished" {
  provisioner "local-exec" {
    command = "echo 'IBM Cloud Private has been successfully deployed.  Resource ID : '${var.dependsOn}"
  }
}
resource "null_resource" "config-output-scripts" {
  connection {
    type = "ssh"
    user = "${var.ssh_user}"  
    private_key = "${base64decode(var.ssh_key_base64)}"    
    host = "${element(var.icp_master, 0)}"
    bastion_host  = "${var.bastion_host}"
    bastion_private_key = "${base64decode(var.bastion_private_key_base64)}"
    bastion_user        = "${var.bastion_user}"
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/mcm/gather_output.sh"
    destination = "/tmp/gather_output.sh"
  }
}

resource "camc_scriptpackage" "get_cluster_config" {
	  depends_on = ["null_resource.config-output-scripts"]
  	program = ["sudo /bin/bash /tmp/gather_output.sh ${var.cluster_CA_domain}"]
  	on_create = true
  	remote_host = "${element(var.icp_master, 0)}"
  	remote_user = "${var.ssh_user}"
  	remote_key = "${var.ssh_key_base64}"  	
  	bastion_host  = "${var.bastion_host}"    
  	bastion_private_key = "${var.bastion_private_key_base64}"
  	bastion_user = "${var.bastion_user}"
}
###
# End gather output for mcm 3.2
###
