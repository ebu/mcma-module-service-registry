provider "mcma" {
  service_registry_url = local.service_url

  mcma_api_key_auth {
    api_key = var.deployment_api_key
  }
}
