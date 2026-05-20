variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "suffix" { type = string }
variable "env_tag" { type = string }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "allowed_source_cidr" { type = string }
variable "tags" { type = map(string) }

# ----- PostgreSQL flexible -----
resource "azurerm_postgresql_flexible_server" "pg" {
  name                          = "pg-mdc-${var.env_tag}-${var.suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "16"
  administrator_login           = var.admin_username
  administrator_password        = var.admin_password
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  public_network_access_enabled = true
  zone                          = "1"
  tags                          = var.tags
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "pg_client" {
  name             = "allowedClient"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = split("/", var.allowed_source_cidr)[0]
  end_ip_address   = split("/", var.allowed_source_cidr)[0]
}

# ----- MySQL flexible -----
resource "azurerm_mysql_flexible_server" "mysql" {
  name                          = "mysql-mdc-${var.env_tag}-${var.suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "8.0.21"
  administrator_login           = var.admin_username
  administrator_password        = var.admin_password
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  tags                          = var.tags
}

resource "azurerm_mysql_flexible_server_firewall_rule" "mysql_client" {
  name                = "allowedClient"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = split("/", var.allowed_source_cidr)[0]
  end_ip_address      = split("/", var.allowed_source_cidr)[0]
}

# ----- Cosmos DB -----
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-mdc-${var.env_tag}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  tags                = var.tags

  capabilities { name = "EnableServerless" }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "db1"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "c1" {
  name                = "c1"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths = ["/pk"]
}

output "postgres_fqdn"    { value = azurerm_postgresql_flexible_server.pg.fqdn }
output "mysql_fqdn"       { value = azurerm_mysql_flexible_server.mysql.fqdn }
output "cosmos_endpoint"  { value = azurerm_cosmosdb_account.cosmos.endpoint }
