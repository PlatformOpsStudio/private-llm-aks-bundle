output "get_credentials_command" {
  value = "az aks get-credentials -g ${azurerm_resource_group.rg.name} -n ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "kv_identity_client_id" {
  description = "Put this in k8s/01-secretprovider.yaml as userAssignedIdentityID"
  value       = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
