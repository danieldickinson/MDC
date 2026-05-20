variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "cluster_name" { type = string }
variable "workspace_id" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  tags                = var.tags

  identity { type = "SystemAssigned" }

  default_node_pool {
    name       = "sys"
    node_count = 2
    vm_size    = "Standard_D2s_v5"
  }

  network_profile {
    network_plugin = "azure"
  }

  microsoft_defender {
    log_analytics_workspace_id = var.workspace_id
  }

  oms_agent {
    log_analytics_workspace_id = var.workspace_id
  }

  azure_policy_enabled       = true
  workload_identity_enabled  = true
  oidc_issuer_enabled        = true
}

output "cluster_name" { value = azurerm_kubernetes_cluster.aks.name }
output "cluster_id"   { value = azurerm_kubernetes_cluster.aks.id }
