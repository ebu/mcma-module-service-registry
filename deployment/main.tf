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

  name = "${var.global_prefix}-service-registry"

  stage_name = var.environment_type

  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  log_group                   = aws_cloudwatch_log_group.main
  api_gateway_logging_enabled = true
  api_gateway_metrics_enabled = true
  xray_tracing_enabled        = true
}
