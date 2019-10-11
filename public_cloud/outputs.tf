
output "icp_public_key" {
  description = "The public key used for boot master to connect via ssh for cluster setup"
  value = "${var.generate_key ? tls_private_key.icpkey.public_key_openssh : var.icp_pub_key}"
}

output "icp_private_key" {
  description = "The public key used for boot master to connect via ssh for cluster setup"
  value = "${var.generate_key ? tls_private_key.icpkey.private_key_pem : var.icp_priv_key}"
}

output "install_complete" {
  depends_on  = ["null_resource.icp_deploy_finished"]
  description = "Boolean value that is set to true when ICP installation process is completed"
  #value       = "${data.external.check_installed.result["installation_finished"]}"
  value       = "${null_resource.icp_deploy_finished.id}"
  #value       = "true"
}

output "icp_version" {
  value = "${var.icp-version}"
}

output "cluster_ips" {
  value = "${local.icp-ips}"
}
