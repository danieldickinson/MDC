variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "server_name" { type = string }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "allowed_source_cidr" { type = string }
variable "workspace_id" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_mssql_server" "srv" {
  name                         = var.server_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
  minimum_tls_version          = "1.2"
  public_network_access_enabled = true
  tags                         = var.tags
}

resource "azurerm_mssql_firewall_rule" "client" {
  name             = "allowedClient"
  server_id        = azurerm_mssql_server.srv.id
  start_ip_address = split("/", var.allowed_source_cidr)[0]
  end_ip_address   = split("/", var.allowed_source_cidr)[0]
}

resource "azurerm_mssql_firewall_rule" "azure" {
  name             = "allowAzure"
  server_id        = azurerm_mssql_server.srv.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "db" {
  name      = "dbpoc"
  server_id = azurerm_mssql_server.srv.id
  sku_name  = "Basic"
  tags      = var.tags
}

resource "azurerm_mssql_server_security_alert_policy" "ssap" {
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mssql_server.srv.name
  state               = "Enabled"
  email_account_admins = true
  retention_days       = 30
}

resource "azurerm_mssql_server_extended_auditing_policy" "audit" {
  server_id                      = azurerm_mssql_server.srv.id
  log_monitoring_enabled         = true
}

resource "azurerm_monitor_diagnostic_setting" "db_diag" {
  name                       = "toLaw"
  target_resource_id         = azurerm_mssql_database.db.id
  log_analytics_workspace_id = var.workspace_id

  enabled_log { category = "SQLSecurityAuditEvents" }
  enabled_log { category = "SQLInsights" }
  metric      { category = "AllMetrics" }
}

output "server_fqdn" { value = azurerm_mssql_server.srv.fully_qualified_domain_name }
