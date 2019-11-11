variable "image_location" {
  description = "URI for image package location, e.g. http://<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz or nfs:<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz"
  default     = ""
}
variable "boot_ipv4_address_private" {

}
variable "boot_ipv4_address" {

}
variable "boot_private_key_pem" {

}
variable "private_network_only" {

}
variable "registry_server" {

}
variable "docker_username" {

}
variable "docker_password" {

}

variable "image_copy_finished"            { description = "Boolean for dependency"}
