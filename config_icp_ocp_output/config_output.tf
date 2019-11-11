resource "null_resource" "config_output_dependsOn" {
  provisioner "local-exec" {
    # Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
	  command = "echo The dependsOn output for config output server module is ${var.dependsOn}"
  }
}
resource "null_resource" "config-output-scripts" {
  depends_on = ["null_resource.config_output_dependsOn"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"    
    private_key = "${length(var.vm_os_private_key) == 0 ? "" : "${base64decode(var.vm_os_private_key)}"}"
    host = "${var.master_node_ip}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/gather_output.sh"
    destination = "/tmp/gather_output.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/config_template"
    destination = "/tmp/config_template"
  }
}

resource "camc_scriptpackage" "get_cluster_config" {
	depends_on = ["null_resource.config-output-scripts"]
  	program = ["sudo /bin/bash /tmp/gather_output.sh -u ${var.icp_admin_user} -c ${var.cluster_name} -as ${var.api_server} -ap ${var.api_port} -rs ${var.reg_server} -rp ${var.reg_port}"]
  	on_create = true
  	remote_host = "${var.master_node_ip}"
  	remote_user = "${var.vm_os_user}"
  	remote_password = "${var.vm_os_password}"
  	remote_key = "${var.vm_os_private_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_password    = "${var.bastion_password}"            	
}

resource "null_resource" "output_create_finished" {
  depends_on = ["camc_scriptpackage.get_cluster_config", "null_resource.config_output_dependsOn"]
  provisioner "local-exec" {
    command = "echo 'Output generated'" 
  }
}