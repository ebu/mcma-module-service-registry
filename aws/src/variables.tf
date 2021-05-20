##################################
# Enable optional variable attributes
##################################

terraform {
  experiments = [module_variable_optional_attrs]
}

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

variable "stage_name" {
  type        = string
  description = "Stage name to be used for the API Gateway deployment"
}

variable "log_group" {
  type        = object({
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

variable "aws_account_id" {
  type        = string
  description = "Account ID to which this module is deployed"
}

variable "aws_region" {
  type        = string
  description = "AWS Region to which this module is deployed"
}

variable "iam_role_path" {
  type        = string
  description = "Path for creation of access role"
  default     = "/"
}

variable "iam_policy_path" {
  type        = string
  description = "Path for creation of access policy"
  default     = "/"
}

#########################
# Configuration
#########################

variable "api_gateway_logging_enabled" {
  type        = bool
  description = "Enable API Gateway logging"
  default     = false
}

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
# Service Definitions
#########################

variable "services" {
  type = list(object({
    name        = string
    auth_type    = optional(string)
    resources   = list(object({
      http_endpoint = string
      resource_type = string
      auth_type     = optional(string)
    }))
    job_type     = optional(string)
    job_profiles = list(object({
      name                    = string
      input_parameters         = list(object({
        parameter_name = string
        parameter_type = string
      }))
      optional_input_parameters = list(object({
        parameter_name = string
        parameter_type = string
      }))
      output_parameters        = list(object({
        parameter_name = string
        parameter_type = string
      }))
    }))
  }))
}
