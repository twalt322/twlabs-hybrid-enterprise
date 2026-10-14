variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vmss_name" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "subnet_id" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key used for the VMSS administrator account"
}