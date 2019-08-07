output "cluster_kube_config"{
  value = "${camc_scriptpackage.get_cluster_config.result["config"]}"
} 

output "cluster_kube_config_ca_cert_data"{
  value = "${camc_scriptpackage.get_cluster_config.result["config_ca_cert_data"]}"
} 

output "registry_ca_cert"{
  value = "${camc_scriptpackage.get_cluster_config.result["docker_cert"]}"
} 

output "dependsOn" { 
	value = "${null_resource.output_create_finished.id}" 
	description="Output Parameter when Module Complete"
}


