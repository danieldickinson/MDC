variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "account_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_cognitive_account" "oai" {
  name                = var.account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"
  custom_subdomain_name        = var.account_name
  public_network_access_enabled = true
  tags                = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.oai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "Standard"
    capacity = 50
  }
}

output "endpoint" { value = azurerm_cognitive_account.oai.endpoint }
