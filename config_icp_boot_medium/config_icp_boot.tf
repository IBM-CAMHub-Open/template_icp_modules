resource "null_resource" "config_icp_boot_dependsOn" {
  provisioner "local-exec" {
    # Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
    command = "echo The dependsOn output for ICP Boot is ${var.dependsOn}"
  }
}

resource "null_resource" "setup_installer" {
  depends_on = ["null_resource.config_icp_boot_dependsOn"]

  count = "${var.enable_bluemix_install == "true" ? length(var.vm_ipv4_address_list) : 0}"

  connection {
    type        = "ssh"
    user        = "${var.vm_os_user}"
    password    = "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host        = "${var.vm_ipv4_address_list[count.index]}"
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
      "mkdir -p ~/ibm-cloud-private-x86_64-${var.icp_version}",
      "cd ~/ibm-cloud-private-x86_64-${var.icp_version}",
      "sudo docker login -u token -p ${var.bluemix_token} registry.ng.bluemix.net",
      "sudo docker pull registry.ng.bluemix.net/mdelder/icp-inception:${var.icp_version}",
      "sudo docker run --rm -v $(pwd):/data -e LICENSE=accept registry.ng.bluemix.net/mdelder/icp-inception:${var.icp_version} cp -r cluster /data",
      "echo \"version: ${var.icp_version}\nimage_repo: registry.ng.bluemix.net/mdelder\nprivate_registry_enabled: true\nprivate_registry_server: registry.ng.bluemix.net\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"docker_username: token\ndocker_password: ${var.bluemix_token}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
    ]
  }

  provisioner "file" {
    source      = "/tmp/${var.random}/icp_hosts"
    destination = "~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/hosts"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo \"version: ${var.icp_version}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"cluster_lb_address: ${var.cluster_lb_address}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"proxy_lb_address: ${var.proxy_lb_address}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",      
      "if [ \"${var.enable_glusterFS}\" = \"true\" ]; then cat ~/glusterfs.txt >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_va}\" = \"true\" ]; then sed -i 's/vulnerability-advisor: disabled/vulnerability-advisor: enabled/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_glusterFS}\" = \"true\" ]; then sed -i 's/storage-glusterfs: disabled/storage-glusterfs: enabled/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_metering}\" = \"false\" ]; then sed -i '/\\bmanagement_services\\b/a\\ \\ metering: disabled' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_monitoring}\" = \"false\" ]; then sed -i '/\\bmanagement_services\\b/a\\ \\ monitoring: disabled' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "echo \"kibana_install: ${var.enable_kibana}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"metering_enabled: ${var.enable_metering}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -i 's/# cluster_name.*/cluster_name: ${var.icp_cluster_name}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -i 's/# cluster_CA_domain.*/cluster_CA_domain: ${var.icp_cluster_name}.${var.vm_domain}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -i 's/default_admin_user.*/default_admin_user: ${var.icp_admin_user}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -i 's/default_admin_password.*/default_admin_password: ${var.icp_admin_password}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "mkdir -p ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/cfc-certs/",
      "sudo chown ${var.vm_os_user} -R ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "cd ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/cfc-certs/ && sudo openssl req -x509 -nodes -sha256 -subj '/CN=${var.icp_cluster_name}.${var.vm_domain}' -days 36500 -newkey rsa:2048 -keyout icp-auth.key -out icp-auth.crt",
      "sudo cp ~/.ssh/id_rsa ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/ssh_key",
      "cd  ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "sudo docker login -u token -p ${var.bluemix_token} registry.ng.bluemix.net",
      "bash -c 'sudo docker run --net=host -t -e LICENSE=accept  -v $(pwd):/installer/cluster registry.ng.bluemix.net/mdelder/icp-inception:${var.icp_version} install | tee /tmp/installlog; test $${PIPESTATUS[0]} -eq 0'",
    ]
  }
}

# Prepare boot node for install (load Docker on boot node) and then install from boot
resource "null_resource" "setup_installer_tar" {
  depends_on = ["null_resource.config_icp_boot_dependsOn"]

  count = "${var.enable_bluemix_install == "false" ? length(var.vm_ipv4_address_list) : 0}"

  connection {
    type        = "ssh"
    user        = "${var.vm_os_user}"
    password    = "${var.vm_os_password}"
    private_key = "${var.private_key}"
    host        = "${var.vm_ipv4_address_list[count.index]}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"            
  }

  provisioner "file" {
    source      = "/tmp/${var.random}/icp_hosts"
    destination = "~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/hosts"
  }

  provisioner "file" {
    source = "${path.module}/scripts/set_ansible_user.sh"
    destination = "~/ibm-cloud-private-x86_64-${var.icp_version}/set_ansible_user.sh"
  }  

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo \"version: ${var.icp_version}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"cluster_lb_address: ${var.cluster_lb_address}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"proxy_lb_address: ${var.proxy_lb_address}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",    
      "if [ \"${var.enable_glusterFS}\" = \"true\" ]; then cat ~/glusterfs.txt >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_va}\" = \"true\" ]; then sed -i 's/vulnerability-advisor: disabled/vulnerability-advisor: enabled/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_glusterFS}\" = \"true\" ]; then sed -i 's/storage-glusterfs: disabled/storage-glusterfs: enabled/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",      
      "if [ \"${var.enable_metering}\" = \"false\" ]; then sed -i '/\\bmanagement_services\\b/a\\ \\ metering: disabled' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "if [ \"${var.enable_monitoring}\" = \"false\" ]; then sed -i '/\\bmanagement_services\\b/a\\ \\ monitoring: disabled' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml; fi",
      "echo \"kibana_install: ${var.enable_kibana}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "echo \"metering_enabled: ${var.enable_metering}\" >> ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      # "echo \"cluster_access_ip: ${var.cluster_access_ip}\" >> ~/${var.icp_version}/cluster/config.yaml",
      "sed -i 's/default_admin_user.*/default_admin_user: ${var.icp_admin_user}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "sed -i 's/default_admin_password.*/default_admin_password: ${var.icp_admin_password}/g' ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/config.yaml",
      "chmod 755  ~/ibm-cloud-private-x86_64-${var.icp_version}/set_ansible_user.sh",
	    "bash -c '~/ibm-cloud-private-x86_64-${var.icp_version}/set_ansible_user.sh ${var.vm_os_user} ${var.icp_version}'",
      "sudo cp ~/.ssh/id_rsa ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster/ssh_key",
      "cd  ~/ibm-cloud-private-x86_64-${var.icp_version}/cluster",
      "export DOCKER_REPO=`sudo docker images |grep inception |grep ${var.icp_version} |awk '{print $1}'`",
      "bash -c 'sudo docker run --net=host -t -e LICENSE=accept  -v $(pwd):/installer/cluster $DOCKER_REPO:${var.icp_version}-ee install | sudo tee -a ~/cfc-install.log; test $${PIPESTATUS[0]} -eq 0'",
    ]
  }
}

resource "null_resource" "icp_install_finished" {
  depends_on = ["null_resource.setup_installer", "null_resource.setup_installer_tar", "null_resource.config_icp_boot_dependsOn"]

  provisioner "local-exec" {
    command = "echo 'ICP middle Tier has been installed.'"
  }
}
