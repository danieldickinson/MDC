variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "app_name" { type = string }
variable "plan_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_service_plan" "plan" {
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "P1v3"
  tags                = var.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = false
  tags                = var.tags

  site_config {
    application_stack { node_version = "20-lts" }
    ftps_state        = "AllAllowed"
  }
}

output "app_url" { value = "https://${azurerm_linux_web_app.app.default_hostname}" }
