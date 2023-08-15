output "auth_type" {
  value = local.auth_type
}

output "service_url" {
  depends_on = [
    azurerm_cosmosdb_sql_container.service,
    azurerm_cosmosdb_sql_database.service,
    azurerm_key_vault.service,
    azurerm_key_vault_access_policy.api_handler,
    azurerm_key_vault_access_policy.deployment,
    azurerm_key_vault_secret.api_key_security_config,
    azurerm_windows_function_app.api_handler,
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

output "local_sensitive_file" {
  value = {
    api_handler = local_sensitive_file.api_handler
  }
}

output "azurerm_windows_function_app" {
  value = {
    api_handler = azurerm_windows_function_app.api_handler
  }
}

output "azurerm_key_vault" {
  value = {
    service = azurerm_key_vault.service
  }
}

output "azurerm_key_vault_access_policy" {
  value = {
    deployment  = azurerm_key_vault_access_policy.deployment
    api_handler = azurerm_key_vault_access_policy.api_handler
  }
}

output "azurerm_key_vault_secret" {
  value = {
    api_handler_security_config = azurerm_key_vault_secret.api_key_security_config
  }
}
