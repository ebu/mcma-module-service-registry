output "auth_type" {
  value = local.auth_type
}

output "service_url" {
  depends_on = [
    azurerm_cosmosdb_sql_container.service,
    azurerm_cosmosdb_sql_database.service,
    azurerm_key_vault.service,
    azurerm_key_vault_access_policy.function_app,
    azurerm_key_vault_access_policy.deployment,
    azurerm_key_vault_secret.api_key_security_config,
    azurerm_windows_function_app.function_app,
  ]
  value = local.service_url
}

# exporting all resources from module
output "azurerm_cosmosdb_sql_database" {
  value = {
    service = azurerm_cosmosdb_sql_database.service
  }
}

output "azurerm_cosmosdb_sql_container" {
  value = {
    service = azurerm_cosmosdb_sql_container.service
  }
}

output "azurerm_storage_container" {
  value = {
    function_app = azurerm_storage_container.function_app
  }
}

output "azurerm_storage_blob" {
  value = {
    function_app = azurerm_storage_blob.function_app
  }
}

output "random_uuid" {
  value = {
    function_app = random_uuid.function_app
  }
}

output "azurerm_resource_group_template_deployment" {
  value = {
    function_app = azurerm_resource_group_template_deployment.function_app
  }
}

output "local_sensitive_file" {
  value = {
    function_app = local_sensitive_file.function_app
  }
}

output "azurerm_windows_function_app" {
  value = {
    function_app = azurerm_windows_function_app.function_app
  }
}

output "azurerm_key_vault" {
  value = {
    service = azurerm_key_vault.service
  }
}

output "azurerm_key_vault_access_policy" {
  value = {
    deployment   = azurerm_key_vault_access_policy.deployment
    function_app = azurerm_key_vault_access_policy.function_app
  }
}

output "azurerm_key_vault_secret" {
  value = {
    api_key_security_config = azurerm_key_vault_secret.api_key_security_config
  }
}
