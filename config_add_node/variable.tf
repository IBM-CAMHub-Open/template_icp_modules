variable "boot_node_IP" {
  description = "IP of Boot Node"
}

variable "node_type" {
  description = "Node type of Node to add to ICP Cluster - worker, management, proxy..."
  default = "worker"
}

variable "new_node_IPs" {
  description = "IP addresses of new nodes"
  type = "list"
}

variable "vm_os_user" {
  description = "Operating System user"
}

variable "vm_os_password" {
  description = "Operating System Password for the Operating System User to access virtual machine"
}

variable "private_key" {
  type = "string"
  description = "Private SSH key Details to the Virtual machine"
}

variable "icp_version" {
  description = "IBM Cloud Private Version"
}

variable "cluster_location" {
  description = "Location to ICP cluster folder"
}

variable "enable_glusterFS" {
  type = "string"
}

variable "dependsOn" {
  description = "Boolean for dependency"
  default = "true"
}
