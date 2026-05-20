variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "storage_account_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_storage_account" "sa" {
  name                          = var.storage_account_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  min_tls_version               = "TLS1_2"
  allow_nested_items_to_be_public = true
  public_network_access_enabled   = true
  tags                          = var.tags

  blob_properties {
    delete_retention_policy   { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
}

resource "azurerm_storage_container" "tcon" {
  name                  = "tcon"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# Defender for Storage v2 + malware scanning + sensitive-data discovery
resource "azapi_resource" "defender" {
  type      = "Microsoft.Security/defenderForStorageSettings@2022-12-01-preview"
  parent_id = azurerm_storage_account.sa.id
  name      = "current"
  body = jsonencode({
    properties = {
      isEnabled = true
      malwareScanning = {
        onUpload = { isEnabled = true, capGBPerMonth = 50 }
      }
      sensitiveDataDiscovery = { isEnabled = true }
      overrideSubscriptionLevelSettings = true
    }
  })
}

output "storage_account_name" { value = azurerm_storage_account.sa.name }
output "storage_account_id"   { value = azurerm_storage_account.sa.id }
