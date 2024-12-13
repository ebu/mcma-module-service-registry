#########################
# Provider registration
#########################

provider "azurerm" {
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# provider "mcma" {
#   alias = "azure"
#
#   service_registry_url = module.service_registry_azure.service_url
#
#   mcma_api_key_auth {
#     api_key = random_password.deployment_api_key.result
#   }
# }

######################
# Resource Group
######################

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.prefix}-${var.azure_location}"
  location = var.azure_location
}

# ######################
# # Storage Account
# ######################

resource "azurerm_storage_account" "storage_account" {
  name                     = format("%.24s", replace("${var.prefix}-${azurerm_resource_group.resource_group.location}", "/[^a-z0-9]+/", ""))
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ######################
# # Cosmos DB
# ######################

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

  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_cosmosdb_sql_database" "cosmosdb_database" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account.name
}

# ########################
# # Application Insights
# ########################

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
  source = "../azure/module"

  prefix = "${var.prefix}-service-registry"

  resource_group    = azurerm_resource_group.resource_group
  storage_account   = azurerm_storage_account.storage_account
  app_insights      = azurerm_application_insights.app_insights
  cosmosdb_account  = azurerm_cosmosdb_account.cosmosdb_account
  cosmosdb_database = azurerm_cosmosdb_sql_database.cosmosdb_database

  use_flex_consumption_plan = true

  api_keys_read_write = [random_password.deployment_api_key.result]

  key_vault_secret_expiration_date = "2200-01-01T00:00:00Z"
}


# resource "mcma_service" "test_service_azure" {
#   provider = mcma.azure
#
#   name      = "Test Service"
#   auth_type = "AWS4"
#
#   resource {
#     resource_type = "JobAssignment"
#     http_endpoint = "https://x5lwk2rh8b.execute-api.eu-west-1.amazonaws.com/job-assignments"
#   }
#
#   job_type        = "QAJob"
#   job_profile_ids = [
#     mcma_job_profile.transcribe_azure.id
#   ]
# }
#
# resource "mcma_job_profile" "transcribe_azure" {
#   provider = mcma.azure
#
#   name = "TranscribeAzure"
#
#   input_parameter {
#     name = "inputFile"
#     type = "Locator"
#   }
#
#   input_parameter {
#     name = "exportFormats"
#     type = "string[]"
#   }
#
#   input_parameter {
#     name     = "keywords"
#     type     = "string[]"
#     optional = true
#   }
#
#   output_parameter {
#     name = "transcription"
#     type = "{[key: string]: S3Locator}"
#   }
# }
