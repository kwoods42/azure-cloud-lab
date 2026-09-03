variable "subscription_id" {}
variable "client_id" {}
variable "tenant_id" {}
variable "client_secret" {
  sensitive = true
}
