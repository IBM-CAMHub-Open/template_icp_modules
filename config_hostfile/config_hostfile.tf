resource "null_resource" "master_dependsOn" {
  provisioner "local-exec" {
# Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
	  command = "echo The dependsOn output for hostfile module is ${var.dependsOn}"
  }
}
resource "null_resource" "generate_hostfile" {
  depends_on = ["null_resource.master_dependsOn"]

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
    source = "/tmp/${var.random}/hosts"
    destination = "/tmp/hosts"
  }
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo rm -fr /etc/hosts.backup",
      "sudo cp /etc/hosts /etc/hosts.backup",
      "sudo sed -i 's/127.0.1.1/#127.0.1.1/g' /etc/hosts",
      "export myhost=`hostname` && sudo sed -i \"/$myhost/d\" /etc/hosts",
      "cat /tmp/hosts | sudo tee -a /etc/hosts",
      "cat /tmp/hosts | cut -f1 -d' ' | xargs -i ssh-keyscan {} | sudo tee -a ~/.ssh/known_hosts"
    ]
  }
}

resource "null_resource" "hostfile-populate" {
  depends_on = ["null_resource.generate_hostfile"]
  provisioner "local-exec" {
    command = "echo 'HostFile pushed to  servers. '" #${var.vm_ipv4_address_list}.'"
  }
}
