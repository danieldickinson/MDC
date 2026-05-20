variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "apim_name" { type = string }
variable "publisher_email" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "MDC CWPP Workshop"
  publisher_email     = var.publisher_email
  sku_name            = "Developer_1"
  identity            { type = "SystemAssigned" }
  tags                = var.tags
}

resource "azurerm_api_management_api" "petstore" {
  name                = "petstore"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Swagger Petstore"
  path                = "petstore"
  protocols           = ["https"]
  service_url         = "https://petstore.swagger.io/v2"
  subscription_required = false

  import {
    content_format = "openapi-link"
    content_value  = "https://petstore.swagger.io/v2/swagger.json"
  }
}

output "gateway_url" { value = azurerm_api_management.apim.gateway_url }
