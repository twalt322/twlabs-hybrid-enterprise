variable "subscription_id" {
  description = "Azure subscription ID for the TF-Projects subscription"
  type        = string
}

variable "home_public_ip" {
  type        = string
  description = "Public WAN IP of the home UniFi gateway"
}