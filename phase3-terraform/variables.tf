variable "subscription_id" {
  description = "Azure subscription ID"
}

variable "client_id" {
  description = "Service principal client ID"
}

variable "tenant_id" {
  description = "Entra ID tenant ID"
}

variable "admin_username" {
  description = "Admin username for all VMs"
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for Windows VMs — supplied via TF_VAR_admin_password from Key Vault at session init"
  sensitive   = true
}

variable "ssh_public_key" {
  description = "RSA public key for Linux VM — must be RSA, not ed25519"
  sensitive   = true
}
