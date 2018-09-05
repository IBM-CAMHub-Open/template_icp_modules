variable "boot_node_ip" {
  description = "IP of host to ssh, boot node or Master1"
}

variable "icp_url" {
  description = "IBM Cloud Private ICP Download Location (http|https|ftp|file)"
}

variable "download_user" {
  type = "string"
  description = "Repository User Name (Optional)"
}

variable "download_user_password" {
  type = "string"
  description = "Repository User Password (Optional)"
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

variable "icp_cluster_name" {
  type = "string"
}

variable "master_node_ip" {
  type = "string"
}

variable "kube_apiserver_secure_port" {
  type = "string"
}

variable "dependsOn" {
  description = "Boolean for dependency"
  default = "true"
}