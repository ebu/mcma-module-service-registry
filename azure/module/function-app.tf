locals {
  function_app_zip_file = "${path.module}/function-app.zip"
  function_app_name     = format("%.32s", replace("${var.prefix}${var.resource_group.location}", "/[^a-z0-9]+/", ""))
  service_fqdn          = "${local.function_app_name}.azurewebsites.net"
  service_url           = "https://${local.service_fqdn}"
  auth_type             = "McmaApiKey"

  storage_container_url = var.use_flex_consumption_plan ? "${var.storage_account.primary_blob_endpoint}${azurerm_storage_container.function_app[0].name}" : ""
  package_url           = var.use_flex_consumption_plan ? "${azurerm_storage_blob.function_app[0].url}${data.azurerm_storage_account_sas.function_app[0].sas}" : ""
}

data "azurerm_storage_account_sas" "function_app" {
  count = var.use_flex_consumption_plan ? 1 : 0

  connection_string = var.storage_account.primary_connection_string
  https_only        = true
  start             = "2000-01-01"
  expiry            = "3000-01-01"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    filter  = false
    tag     = false
  }
}

resource "azurerm_storage_container" "function_app" {
  count = var.use_flex_consumption_plan ? 1 : 0

  name                  = var.prefix
  storage_account_id    = var.storage_account.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "function_app" {
  count = var.use_flex_consumption_plan ? 1 : 0

  name                   = "function_${filesha256(local.function_app_zip_file)}.zip"
  storage_account_name   = var.storage_account.name
  storage_container_name = azurerm_storage_container.function_app[0].name
  type                   = "Block"
  source                 = local.function_app_zip_file
}

resource "random_uuid" "function_app" {
  count = var.use_flex_consumption_plan ? 1 : 0
}

resource "azurerm_resource_group_template_deployment" "function_app" {
  count = var.use_flex_consumption_plan ? 1 : 0

  name                = "${var.prefix}-function-app"
  resource_group_name = var.resource_group.name
  deployment_mode     = "Incremental"

  template_content = file("${path.module}/function-app.template.json")
  parameters_content = jsonencode({
    location = {
      value = var.resource_group.location
    }
    storageAccountName = {
      value = var.storage_account.name
    }
    storageContainerUrl = {
      value = local.storage_container_url
    }
    appInsightsInstrumentationKey = {
      value = var.app_insights.instrumentation_key
    }
    servicePlanId = {
      value = local.service_plan_id
    }
    functionAppName = {
      value = local.function_app_name
    }
    functionAppRuntime = {
      value = "node"
    }
    functionAppRuntimeVersion = {
      value = "20"
    }
    maximumInstanceCount = {
      value = 100
    }
    instanceMemoryMB = {
      value = 2048
    }
    packageUrl = {
      value = local.package_url
    }
    roleNameGuid = {
      value = random_uuid.function_app[0].result
    }
    mcmaTableName = {
      value = azurerm_cosmosdb_sql_container.service.name
    }
    mcmaCosmosDbDatabaseName = {
      value = local.cosmosdb_database_name
    }
    mcmaCosmosDbEndpoint = {
      value = var.cosmosdb_account.endpoint
    }
    mcmaCosmosDbKey = {
      value = var.cosmosdb_account.primary_key
    }
    mcmaCosmosDbLocation = {
      value = var.resource_group.location
    }
    mcmaKeyVaultUrl = {
      value = azurerm_key_vault.service.vault_uri
    }
    mcmaApiKeySecurityConfigSecretId = {
      value = azurerm_key_vault_secret.api_key_security_config.name
    }
    mcmaApiKeySecurityConfigHash = {
      value = sha256(azurerm_key_vault_secret.api_key_security_config.value)
    }
  })
}

resource "local_sensitive_file" "function_app" {
  count = var.use_flex_consumption_plan ? 0 : 1

  filename = ".terraform/${filesha256(local.function_app_zip_file)}.zip"
  source   = local.function_app_zip_file
}

resource "azurerm_windows_function_app" "function_app" {
  count = var.use_flex_consumption_plan ? 0 : 1

  name                = local.function_app_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  storage_account_name       = var.storage_account.name
  storage_account_access_key = var.storage_account.primary_access_key
  service_plan_id            = local.service_plan_id

  builtin_logging_enabled = false

  site_config {
    application_stack {
      node_version = "~20"
    }

    elastic_instance_minimum               = var.function_elastic_instance_minimum
    application_insights_connection_string = var.app_insights.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  https_only      = true
  zip_deploy_file = local_sensitive_file.function_app[0].filename

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"

    MCMA_PUBLIC_URL = local.service_url

    MCMA_TABLE_NAME            = azurerm_cosmosdb_sql_container.service.name
    MCMA_COSMOS_DB_DATABASE_ID = local.cosmosdb_database_name
    MCMA_COSMOS_DB_ENDPOINT    = var.cosmosdb_account.endpoint
    MCMA_COSMOS_DB_KEY         = var.cosmosdb_account.primary_key
    MCMA_COSMOS_DB_REGION      = var.resource_group.location

    MCMA_KEY_VAULT_URL                     = azurerm_key_vault.service.vault_uri
    MCMA_API_KEY_SECURITY_CONFIG_SECRET_ID = azurerm_key_vault_secret.api_key_security_config.name
    MCMA_API_KEY_SECURITY_CONFIG_HASH      = sha256(azurerm_key_vault_secret.api_key_security_config.value)
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id = azurerm_key_vault.service.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.use_flex_consumption_plan ? jsondecode(azurerm_resource_group_template_deployment.function_app[0].output_content).functionAppIdentityPrincipalId.value : azurerm_windows_function_app.function_app[0].identity[0].principal_id

  secret_permissions = ["Get"]
}
