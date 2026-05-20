variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "workspace_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Sentinel onboarding (legacy onboardingStates) via AzAPI for parity with Bicep
resource "azapi_resource" "sentinel" {
  type      = "Microsoft.SecurityInsights/onboardingStates@2023-11-01"
  parent_id = azurerm_log_analytics_workspace.law.id
  name      = "default"
  body      = jsonencode({ properties = {} })
}

# MDC → Sentinel data connector
resource "azapi_resource" "mdc_connector" {
  type      = "Microsoft.SecurityInsights/dataConnectors@2023-11-01"
  parent_id = azurerm_log_analytics_workspace.law.id
  name      = uuid()
  body = jsonencode({
    kind = "MicrosoftDefenderAdvancedThreatProtection"
    properties = {
      tenantId  = data.azurerm_client_config.current.tenant_id
      dataTypes = { alerts = { state = "enabled" } }
    }
  })
  lifecycle { ignore_changes = [name] }
  depends_on = [azapi_resource.sentinel]
}

data "azurerm_client_config" "current" {}

output "workspace_id"   { value = azurerm_log_analytics_workspace.law.id }
output "workspace_name" { value = azurerm_log_analytics_workspace.law.name }
output "workspace_key" {
  value     = azurerm_log_analytics_workspace.law.primary_shared_key
  sensitive = true
}
