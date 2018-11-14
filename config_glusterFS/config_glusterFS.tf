# Create ICp config.yaml glusterfs update file
resource "null_resource" "config_glusterfs_dependsOn" {
  provisioner "local-exec" {
    command = "echo The dependsOn output for glusterFS is ${var.dependsOn}"
  }
}

data "local_file" "example" {
  depends_on = ["null_resource.config_glusterfs_dependsOn"]
  count      = "${var.enable_glusterFS == "true" ? 1 : 0}"
  filename   = "${path.module}/scripts/generate_glusterfs_txt.sh"
}

resource "local_file" "generate_glusterfs_txt" {
  depends_on = ["null_resource.config_glusterfs_dependsOn"]
  count      = "${var.enable_glusterFS == "true" ? 1 : 0}"
  content    = "${data.local_file.example.content}"
  filename   = "/tmp/${var.random}/generate_glusterfs_txt.sh"
}

resource "null_resource" "generate_glusterfs_txt" {
  depends_on = ["local_file.generate_glusterfs_txt"]
  count      = "${var.enable_glusterFS == "true" ? 1 : 0}"

  provisioner "local-exec" {
    command = "bash -c '/tmp/${var.random}/generate_glusterfs_txt.sh ${var.gluster_volumetype_none} ${var.icp_version} ${var.random} ${var.vm_ipv4_address_str}'"
  }
}

resource "null_resource" "load_device_script" {
  depends_on = ["null_resource.generate_glusterfs_txt"]
  count      = "${var.enable_glusterFS == "true" ? length(var.vm_ipv4_address_list) : 0}"

  #  count = "${length(var.vm_ipv4_address_list)}"
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
    source      = "${path.module}/scripts/interpolate_device_symlink.sh"
    destination = "/tmp/interpolate_device_symlink.sh"
  }

  provisioner "file" {
    source      = "/tmp/${var.random}/glusterfs.txt"
    destination = "/tmp/glusterfs.txt"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/copy_glusterfs_txt.sh"
    destination = "/tmp/copy_glusterfs_txt.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 /tmp/interpolate_device_symlink.sh",
      "/tmp/interpolate_device_symlink.sh",
      "chmod 755 /tmp/copy_glusterfs_txt.sh",
      "/tmp/copy_glusterfs_txt.sh -p ${var.vm_os_password} -i ${var.boot_vm_ipv4_address}"
    ]
  }
}

resource "null_resource" "load_gluster_prereqs" {
  depends_on = ["null_resource.generate_glusterfs_txt", "null_resource.load_device_script"]
  count      = "${var.enable_glusterFS == "true" ? length(var.vm_ipv4_address_list) : 0}"

  #  count = "${length(var.vm_ipv4_address_list)}"
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
    source      = "${path.module}/scripts/worker_prereqs.sh"
    destination = "/tmp/worker_prereqs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "chmod 755 /tmp/worker_prereqs.sh",
      "/tmp/worker_prereqs.sh",
    ]
  }
}

resource "null_resource" "post_populate_glusterfs_end" {
  depends_on = ["null_resource.load_gluster_prereqs", "null_resource.config_glusterfs_dependsOn", "null_resource.load_device_script", "local_file.generate_glusterfs_txt", "null_resource.generate_glusterfs_txt"]

  provisioner "local-exec" {
    command = "${format("echo 'the end of gluster FS' ")}"
  }
}
