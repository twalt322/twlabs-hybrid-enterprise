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

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS servers for the virtual network"
}

variable "onprem_address_space" {
  description = "On-premises network allowed to access Azure workloads"
  type        = string
}

variable "dns_server_ip" {
  description = "On-premises DNS server used by Azure workloads"
  type        = string
}