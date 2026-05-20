variable "workspace_resource_id" { type = string }

locals {
  plans = {
    VirtualMachines                = "P2"
    Containers                     = null
    StorageAccounts                = "DefenderForStorageV2"
    SqlServers                     = null
    SqlServerVirtualMachines       = null
    AppServices                    = null
    KeyVaults                      = "PerKeyVault"
    Arm                            = "PerSubscription"
    Dns                            = null
    OpenSourceRelationalDatabases  = null
    CosmosDbs                      = null
    Api                            = "P1"
    AI                             = null
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_security_center_subscription_pricing" "this" {
  for_each      = local.plans
  tier          = "Standard"
  resource_type = each.key
  subplan       = each.value
}

resource "azurerm_security_center_workspace" "default" {
  scope_id     = data.azurerm_subscription.current.id
  workspace_id = var.workspace_resource_id
}

resource "azurerm_security_center_auto_provisioning" "default" {
  auto_provision = "On"
}
