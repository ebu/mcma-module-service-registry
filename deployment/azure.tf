######################
# Resource Group
######################

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.prefix}-${var.azure_location}"
  location = var.azure_location
}

######################
# App Storage Account
######################

resource "azurerm_storage_account" "app_storage_account" {
  name                     = format("%.24s", replace("${var.prefix}-${azurerm_resource_group.resource_group.location}", "/[^a-z0-9]+/", ""))
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


######################
# App Service Plan
######################

resource "azurerm_service_plan" "app_service_plan" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

######################
# Cosmos DB
######################

resource "azurerm_cosmosdb_account" "cosmosdb_account" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Strong"
  }

  geo_location {
    failover_priority = 0
    location          = azurerm_resource_group.resource_group.location
  }
}


########################
# Application Insights
########################

resource "azurerm_log_analytics_workspace" "app_insights" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
}

resource "azurerm_application_insights" "app_insights" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  workspace_id        = azurerm_log_analytics_workspace.app_insights.id
  application_type    = "web"
}

#########################
# Service Registry Module
#########################

module "service_registry_azure" {
  source = "../azure/build/staging"

  prefix = "${var.prefix}-service-registry"

  resource_group      = azurerm_resource_group.resource_group
  app_storage_account = azurerm_storage_account.app_storage_account
  app_service_plan    = azurerm_service_plan.app_service_plan
  app_insights        = azurerm_application_insights.app_insights
  cosmosdb_account    = azurerm_cosmosdb_account.cosmosdb_account

  azure_tenant_id = var.azure_tenant_id
}
