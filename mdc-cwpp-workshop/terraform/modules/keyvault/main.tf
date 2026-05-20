variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vault_name" { type = string }
variable "tags" { type = map(string) }

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                          = var.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# Grant the current principal Key Vault Secrets Officer so we can write demo secrets
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "demo" {
  for_each     = toset(["demo-db-password", "demo-api-key", "demo-storage-key"])
  name         = each.key
  value        = "fake-not-real-please-rotate"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_admin]
}

output "vault_name" { value = azurerm_key_vault.kv.name }
output "vault_uri"  { value = azurerm_key_vault.kv.vault_uri }
