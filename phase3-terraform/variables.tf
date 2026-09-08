variable "subscription_id" {}
variable "client_id" {}
variable "tenant_id" {}

variable "admin_username" {
  description = "Admin username for both VMs"
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VM"
  sensitive   = true
}
