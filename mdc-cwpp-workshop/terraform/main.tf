resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

locals {
  suffix = random_string.suffix.result
  tags   = var.tags
}

resource "azurerm_resource_group" "edge" {
  name     = "rg-mdc-${var.env_tag}-edge"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "servers" {
  name     = "rg-mdc-${var.env_tag}-servers"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "data" {
  name     = "rg-mdc-${var.env_tag}-data"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "apps" {
  name     = "rg-mdc-${var.env_tag}-apps"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  location            = var.location
  resource_group_name = azurerm_resource_group.edge.name
  workspace_name      = "law-mdc-${var.env_tag}-${local.suffix}"
  tags                = local.tags
}

module "mdc_plans" {
  source                = "./modules/mdc-plans"
  workspace_resource_id = module.monitoring.workspace_id
}

module "servers" {
  source              = "./modules/servers"
  location            = var.location
  resource_group_name = azurerm_resource_group.servers.name
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  allowed_source_cidr = var.allowed_source_cidr
  tags                = local.tags
}

module "containers" {
  source              = "./modules/containers"
  location            = var.location
  resource_group_name = azurerm_resource_group.servers.name
  cluster_name        = "aks-mdc-${var.env_tag}-${local.suffix}"
  workspace_id        = module.monitoring.workspace_id
  tags                = local.tags
}

module "storage" {
  source                = "./modules/storage"
  location              = var.location
  resource_group_name   = azurerm_resource_group.data.name
  storage_account_name  = "stomdc${var.env_tag}${local.suffix}"
  tags                  = local.tags
}

module "sql" {
  source              = "./modules/sql"
  location            = var.location
  resource_group_name = azurerm_resource_group.data.name
  server_name         = "sql-mdc-${var.env_tag}-${local.suffix}"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  allowed_source_cidr = var.allowed_source_cidr
  workspace_id        = module.monitoring.workspace_id
  tags                = local.tags
}

module "appservice" {
  source              = "./modules/appservice"
  location            = var.location
  resource_group_name = azurerm_resource_group.apps.name
  app_name            = "app-mdc-${var.env_tag}-${local.suffix}"
  plan_name           = "plan-mdc-${var.env_tag}-${local.suffix}"
  tags                = local.tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  location            = var.location
  resource_group_name = azurerm_resource_group.edge.name
  vault_name          = "kv-mdc${var.env_tag}${local.suffix}"
  tags                = local.tags
}

module "databases" {
  source              = "./modules/databases"
  location            = var.location
  resource_group_name = azurerm_resource_group.data.name
  suffix              = local.suffix
  env_tag             = var.env_tag
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  allowed_source_cidr = var.allowed_source_cidr
  tags                = local.tags
}

module "apim" {
  source              = "./modules/apim"
  location            = var.location
  resource_group_name = azurerm_resource_group.apps.name
  apim_name           = "apim-mdc-${var.env_tag}-${local.suffix}"
  publisher_email     = lookup(local.tags, "owner", "owner@contoso.com")
  tags                = local.tags
}

module "openai" {
  source              = "./modules/openai"
  location            = var.location
  resource_group_name = azurerm_resource_group.apps.name
  account_name        = "oai-mdc-${var.env_tag}-${local.suffix}"
  tags                = local.tags
}
