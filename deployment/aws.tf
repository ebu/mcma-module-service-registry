#########################
# Provider registration
#########################

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "mcma" {
  alias = "aws"

  service_registry_url       = module.service_registry_aws.service_url
  service_registry_auth_type = module.service_registry_aws.auth_type

  aws4_auth {
    profile = var.aws_profile
    region  = var.aws_region
  }

  mcma_api_key_auth {
    api_key = random_password.deployment_api_key.result
  }
}

############################################
# Cloud watch log group for central logging
############################################

resource "aws_cloudwatch_log_group" "main" {
  name = "/mcma/${var.prefix}"
}

#########################
# Service Registry Module
#########################
module "service_registry_aws" {
  source = "../aws/build/staging"

  prefix = "${var.prefix}-service-registry"

  aws_region  = var.aws_region
  aws_profile = var.aws_profile

  log_group                   = aws_cloudwatch_log_group.main
  api_gateway_metrics_enabled = true
  xray_tracing_enabled        = true
  enhanced_monitoring_enabled = true

  api_keys_read_write = [random_password.deployment_api_key.result]

  #  api_security_auth_type = "AWS4"
}

resource "mcma_service" "test_service_aws" {
  provider = mcma.aws

  name      = "Test Service"
  auth_type = "AWS4"

  resource {
    resource_type = "JobAssignment"
    http_endpoint = "https://x5lwk2rh8b.execute-api.eu-west-1.amazonaws.com/job-assignments"
  }

  job_type        = "QAJob"
  job_profile_ids = [
    mcma_job_profile.transcribe_aws.id
  ]
}

resource "mcma_job_profile" "transcribe_aws" {
  provider = mcma.aws

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
