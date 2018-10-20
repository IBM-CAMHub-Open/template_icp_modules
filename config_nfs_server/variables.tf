variable "vm_os_password" {
  type = "string"
  description = "Password for the Operating System User to access virtual machine"
}
variable "vm_os_user" {
  type = "string"
  description = "User for the Operating System User to access virtual machine"
}
variable "vm_ipv4_address_list" {
  description = "IPv4 address for vNIC configuration"
  type = "list"
}
variable "dependsOn" {
  default = "true"
  description = "Boolean for dependency"
}
variable "vm_os_private_key" {
  default = ""
}
variable "nfs_drive" {
  default = "/dev/sdb"
  description = "Drive that should be formatted and used as NFS"
}
variable "nfs_link_folders" {
  type        = "string"
  default     = "/var/lib/registry,/var/lib/icp/audit"
  description = "Directories to be mounted and dynamic linked to the NFS Share"
}
variable "enable_nfs" { 
  type = "string" 
  default = "true"
  description = "If true, create NFS server VM and mounts worker nodes to server."
}
