
##############################################################
# OpenStack data for provider
##############################################################
variable "enable_vm" {
  type = "string"
  default = "true"
}

#Variable : vm_-name
variable "vm_name" {
  type = "list"
}
variable "count" {
  type = "string"
  default = "1"
}

#########################################################
##### Resource : vm_
#########################################################
variable "vm_public_ip_pool" {
  type    = "string"
}

variable "vm_image_id" {
  type    = "string"
}

variable "vm_flavor_id" {
  type    = "string"
}

variable "vm_security_groups" {
  type    = "list"
}

variable "vm_os_password" {
  type = "string"
  description = "Operating System Password for the Operating System User to access virtual machine"
}
variable "vm_os_user" {
  type = "string"
  description = "Operating System user for the Operating System User to access virtual machine"
  }

variable "vm_private_ssh_key" { }

variable "vm_public_ssh_key" { }

variable "vm_domain" {
  description = "Domain Name of virtual machine"
}

variable "vm_ipv4_address" {
  default = []
  description = "IPv4 address for vNIC configuration"
  type = "list"
}

variable "vm_disk1_size" {
  description = "Size of template disk volume"
}

variable "vm_disk1_delete_on_termination" {
  type = "string"
  description = "Delete template disk volume when the virtual machine is deleted"
  default = "false"
}

variable "vm_disk2_enable" {
  type = "string"
  description = "Enable a Second disk on VM"
} 

variable "vm_disk2_size" {
  description = "Size of template disk volume"
}

variable "vm_disk2_delete_on_termination" {
  type = "string"
  description = "Delete template disk volume when the virtual machine is deleted"
  default = "false"
}

variable "dependsOn" {
  default = "true"
  description = "Boolean for dependency"
}

variable "random" {
  type = "string"
  description = "Random String Generated"
}