#########################
# Provider registration
#########################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}


############################################
# Cloud watch log group for central logging
############################################

resource "aws_cloudwatch_log_group" "main" {
  name = "/mcma/${var.global_prefix}"
}

#########################
# Service Registry Module
#########################
module "service_registry_aws" {
  source = "../aws/build/staging"

  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region
  log_group      = aws_cloudwatch_log_group.main
  module_prefix  = "${var.global_prefix}-service-registry"
  stage_name     = var.environment_type

  api_gateway_logging_enabled = false
  api_gateway_metrics_enabled = false
  xray_tracing_enabled        = false
}
