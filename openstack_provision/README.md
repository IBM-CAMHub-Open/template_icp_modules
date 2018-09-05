<!---
Copyright IBM Corp. 2018, 2018
--->

# OpenStack Virtual Machine Provision Module

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| count |  | string | `1` | no |
| dependsOn | Boolean for dependency | string | `true` | no |
| vm_disk1_delete_on_termination | Delete template disk volume when the virtual machine is deleted | string | `true` | no |
| vm_disk1_size | Size of template disk volume | string | - | yes |
| vm_disk2_enable | Enable a Second disk on VM | string | - | yes |
| vm_disk2_delete_on_termination | Delete template disk volume when the virtual machine is deleted | string | `true` | no |
| vm_disk2_size | Size of template disk volume | string | - | yes |
| vm_private_ip_pool | Pool from which the IP is retrieved from | string | - | yes |
| vm_ipv4_address | IP Address for this instance | string | - | yes |
| vm_image_id | OpenStack Operating System image id | string | - | yes |
| vm_flavor_id | OpenStack flavor id | string | - | yes |
| vm_security_groups | OpenStack security groups to assign to this instance | list | - | yes |
| vm_domain | Domain Name of virtual machine | string | - | yes |
| vm_name | Variable : vm_-name | string | - | yes |
| vm_os_password | Operating System Password for the Operating System User to access virtual machine | string | - | yes |
| vm_os_user | Operating System user for the Operating System User to access virtual machine | string | - | yes |
| vm_private_ssh_key |  | string | - | yes |
| vm_public_ssh_key |  | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| dependsOn | Output Parameter when Module Complete |
