output "registry_ca_cert"{
  value = "${camc_scriptpackage.get_cluster_config.result["docker_cert"]}"
} 

output "icp_install_dir"{
  value = "${camc_scriptpackage.get_cluster_config.result["install_dir"]}"
} 