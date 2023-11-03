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

variable "log_group" {
  type = object({
    id   = string
    arn  = string
    name = string
  })
  description = "Log group used by MCMA Event tracking"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources"
  default     = {}
}

#########################
# AWS Variables
#########################

variable "aws_region" {
  type        = string
  description = "AWS Region to which this module is deployed"
}

// TODO Delete this variable when MCMA terraform provider gets removed
variable "aws_profile" {
  type        = string
  description = "AWS shared credentials profile used to connect to service registry"
  default     = null
}

variable "iam_role_path" {
  type        = string
  description = "Path for creation of access role"
  default     = "/"
}

variable "iam_permissions_boundary" {
  type        = string
  description = "IAM permissions boundary"
  default     = null
}

#########################
# Configuration
#########################

variable "api_gateway_metrics_enabled" {
  type        = bool
  description = "Enable API Gateway metrics"
  default     = false
}

variable "xray_tracing_enabled" {
  type        = bool
  description = "Enable X-Ray tracing"
  default     = false
}

variable "enhanced_monitoring_enabled" {
  type        = bool
  description = "Enable CloudWatch Lambda Insights"
  default     = false
}

#########################
# MCMA Api Key Authentication
#########################

variable "api_keys_read_only" {
  type    = list(string)
  default = []
}

variable "api_keys_read_write" {
  type    = list(string)
  default = []
}

#########################
# Selecting API Authentication
#########################

variable "api_security_auth_type" {
  type    = string
  default = "McmaApiKey"

  validation {
    condition     = var.api_security_auth_type == null || can(regex("^(AWS4|McmaApiKey)$", var.api_security_auth_type))
    error_message = "ERROR: Valid auth types are \"AWS4\" and \"McmaApiKey\"!"
  }
}
