variable "vm_os_password"       { type = "string"  description = "Operating System Password for the Operating System User to access virtual machine"}
variable "vm_os_user"           { type = "string"  description = "Operating System user for the Operating System User to access virtual machine"}
variable "ocp_installer"      { type= "string"      description = "IPv4 Address's in List format"}
variable "private_key"          { type = "string"  description = "Private SSH key Details to the Virtual machine"}
variable "random"               { type = "string" description = "Random String Generated"}
variable "dependsOn"            { default = "true"  description = "Boolean for dependency"}
variable "icp_version"          { type="string" description = "IBM Cloud Private Version"}
variable "icp_admin_user"       { type="string" description = "IBM Cloud Private Admin Username"}
variable "icp_admin_password"   { type="string" description = "IBM Cloud Private Admin Password"}

variable "icp_master_host" {
  type = "string"
}

variable "icp_proxy_host" {
  type = "string"
}

variable "icp_management_host" {
  type = "string"
}

variable "ocp_master_host" {
  type = "string"
}

variable "ocp_vm_domain_name" {
  type = "string"
}

variable "ocp_enable_glusterfs" {
  type = "string"
}

variable "icp_cluster_name" {
  type = "string"
}