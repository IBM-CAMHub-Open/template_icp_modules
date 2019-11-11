variable "dependsOn" {
  default = "true"
  description = "Boolean for dependency"
}

variable "master_node_ip" {
  type = "string"
  description = "ICP Master Node IP"
}

variable "vm_os_user" {
  type = "string"
}

variable "vm_os_password" {
  type = "string"
}

variable "vm_os_private_key" {
  type = "string"
}

variable "cluster_name" {
  type = "string"
  description = "ICP Cluster name to be used in generated kube config"
}

variable "api_server" {
  type = "string"
  description = "ICP API server host or IP"
}

variable "api_port" {
  type = "string"
  description = "ICP API port"
}

variable "reg_server" {
  type = "string"
  description = "Private docker registry server CA domain or host name"
}

variable "reg_port" {
  type = "string"
  description = "Private docker registry port"
}

variable "icp_admin_user" {
  type = "string"
  default = "admin"
}
