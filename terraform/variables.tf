variable "location" {
  type    = string
  default = "eastus2"
}

variable "resource_group" {
  type    = string
  default = "rg-private-llm"
}

variable "cluster_name" {
  type    = string
  default = "aks-private-llm"
}

variable "gpu_vm_size" {
  type    = string
  default = "Standard_NC24ads_A100_v4"
}

variable "key_vault_name" {
  type = string # must be globally unique
}
