#########################
# Environment Variables
#########################

variable "name" {
  type        = string
  description = "Optional variable to set a custom name for this service in the service registry"
  default     = "Service Registry"
}

variable "prefix" {
  type        = string
  description = "Prefix for all managed resources in this module"
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "azure_tenant_id" {
  type = string
}

###########################
# Azure accounts and plans
###########################

variable "app_storage_account" {
  type = object({
    name               = string
    primary_access_key = string
  })
}

variable "app_service_plan" {
  type = object({
    id   = string
    name = string
  })
}

variable "cosmosdb_account" {
  type = object({
    name        = string
    endpoint    = string
    primary_key = string
  })
}

variable "app_insights" {
  type = object({
    name                = string
    connection_string   = string
    instrumentation_key = string
  })
}

#######################
# API authentication
#######################

variable "api_keys_read_only" {
  type = list(string)
  default = []
}

variable "api_keys_read_write" {
  type = list(string)
  default = []
}

########################
# Deployment API Key
########################
variable "deployment_api_key" {
  type = string
}
