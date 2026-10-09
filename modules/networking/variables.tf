variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "workload_subnet_name" {
  type = string
}

variable "workload_subnet_prefixes" {
  type = list(string)
}

variable "gateway_subnet_name" {
  type = string
}

variable "gateway_subnet_prefixes" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "nsg_name" {
  type = string
}