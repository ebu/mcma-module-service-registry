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

  prefix = "${var.global_prefix}-service-registry"

  stage_name = var.environment_type

  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  log_group                   = aws_cloudwatch_log_group.main
  api_gateway_logging_enabled = true
  api_gateway_metrics_enabled = true
  xray_tracing_enabled        = true

  services = [ local.service1, local.service2 ]
}

locals {
  service1 = {
    name        = "BenchmarkSTT Service"
    auth_type    = "AWS4"
    resources   = [
      {
        http_endpoint = "https://x5lwk2rh8b.execute-api.eu-west-1.amazonaws.com/dev/job-assignments"
        resource_type = "JobAssignment"
      }
    ]
    job_type     = "QAJob"
    job_profiles = [
      {
        name: "BenchmarkSTT",
        input_parameters: [
          {
            parameter_name: "inputFile",
            parameter_type: "Locator"
          },
          {
            parameter_name: "referenceFile",
            parameter_type: "Locator"
          },
          {
            parameter_name: "outputLocation",
            parameter_type: "Locator"
          }
        ],
        optional_input_parameters: []
        output_parameters: [
          {
            parameter_name: "outputFile",
            parameter_type: "Locator"
          }
        ]
      }]
  }
  service2 = {
    name        = "BenchmarkSTT Service 2"
    auth_type    = "AWS4"
    resources   = [
      {
        http_endpoint = "https://x5lwk2rh8b.execute-api.eu-west-1.amazonaws.com/dev/job-assignments"
        resource_type = "JobAssignment"
      }
    ]
    job_profiles = []
  }
}
