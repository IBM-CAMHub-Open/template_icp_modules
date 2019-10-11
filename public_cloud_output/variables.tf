variable "cluster_CA_domain" {
  type = "string"
  description = "Cluster CA domain name"
}

variable "icp_master" {
  type        = "list"
  description =  "IP address of ICP Masters."
}

variable "ssh_user" {
  type = "string"
  description = "Username to ssh into the ICP cluster."
}

variable "ssh_key_base64" {
  type = "string"
  description = "Base64 encoded content of private ssh key"
}

variable "bastion_host" {
  type = "string"
  description = "Specify hostname or IP to connect to nodes through a SSH bastion host."
}

variable "bastion_user" {
  type = "string"
  default = ""
  description = "Username to ssh into the bastion host. This is typically the ssh user but can vary based on cloud vendor."
}

variable "bastion_private_key_base64" {
  type = "string"
  default = ""
  description = "Base64 encoded private key for bastion host. This is typically the ssh key but can vary based on cloud vendor."
}

variable "dependsOn"            { description = "Boolean for dependency"}
