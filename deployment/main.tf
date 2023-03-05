#########################
# Provider registration
#########################

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "mcma" {
  service_registry_url = module.service_registry_aws.service_url

  aws4_auth {
    profile = var.aws_profile
    region  = var.aws_region
  }
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

  aws_region     = var.aws_region
  aws_profile    = var.aws_profile

  log_group                   = aws_cloudwatch_log_group.main
  api_gateway_metrics_enabled = true
  xray_tracing_enabled        = true
  enhanced_monitoring_enabled = true
}

resource "mcma_service" "test_service" {
  name      = "Test Service"
  auth_type = "AWS4"

  resource {
    resource_type = "JobAssignment"
    http_endpoint = "https://x5lwk2rh8b.execute-api.eu-west-1.amazonaws.com/dev/job-assignments"
  }

  job_type = "QAJob"
  job_profile_ids = [
    mcma_job_profile.transcribe.id
  ]
}

resource "mcma_job_profile" "transcribe" {
  name = "TranscribeAzure"

  input_parameter {
    name = "inputFile"
    type = "Locator"
  }

  input_parameter {
    name = "exportFormats"
    type = "string[]"
  }

  input_parameter {
    name     = "keywords"
    type     = "string[]"
    optional = true
  }

  output_parameter {
    name = "transcription"
    type = "{[key: string]: S3Locator}"
  }
}
