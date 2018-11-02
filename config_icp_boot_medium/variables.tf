variable "vm_os_password" {
  type = "string"
  description = "Operating System Password for the Operating System User to access virtual machine"
}

variable "vm_os_user" {
  type = "string"
  description = "Operating System user for the Operating System User to access virtual machine"
}

variable "vm_ipv4_address_list" {
  type = "list"
  description = "IPv4 Address's in List format"
}

variable "private_key" {
  type = "string"
  description = "Private SSH key Details to the Virtual machine"
}

variable "random" {
  type = "string"
  description = "Random String Generated"
}

variable "dependsOn" {
  default = "true"
  description = "Boolean for dependency"
}

variable "enable_kibana" {
  type = "string"
  description = "Enable IBM Cloud Private Kibana"
}

variable "enable_bluemix_install" {
  type = "string"
  default = "false"
  description = "Enable install from bluemix repository"
}

variable "bluemix_token" {
  type = "string"
  description = "Bluemix token"
}

variable "enable_metering" {
  type = "string"
  description = "Enable IBM Cloud Private Metering"
}

variable "icp_version" {
  type = "string"
  description = "IBM Cloud Private Version"
}

variable "kub_version" {
  type = "string"
  description = "Kubernetes Version"
}

variable "icp_cluster_name" {
  type = "string"
  description = "IBM Cloud Private Cluster Name"
}

variable "vm_domain" {
  type = "string"
  description = "IBM Cloud Private Domain Name"
}

variable "icp_admin_user" {
  type = "string"
  description = "IBM Cloud Private Admin Username"
}

variable "icp_admin_password" {
  type = "string"
  description = "IBM Cloud Private Admin Password"
}

variable "cluster_lb_address" {
  type = "string"
  default = "none"
  description = "IP Address of the Cluster Load Balancer"
}

variable "proxy_lb_address" {
  type = "string"
  default = "none"
  description = "IP Address of the Proxy Load Balancer"
}

variable "enable_glusterFS"     { type = "string" description = "Enable GlusterFS on Worker nodes?"}
variable "enable_monitoring"    { type="string" description = "Enable IBM Cloud Private Monitoring"}
variable "enable_va"            { type="string" description = "Enable IBM Cloud Private Vulnerability Advisor"}