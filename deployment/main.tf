#########################
# Provider registration
#########################

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "azurerm" {
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  features {}
}

resource "random_password" "deployment_api_key" {
  length  = 32
  special = false
}
