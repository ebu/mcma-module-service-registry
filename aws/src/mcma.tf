provider "mcma" {
  service_registry_url = aws_apigatewayv2_stage.service_api.invoke_url

  aws4_auth {
    profile = var.aws_profile
    region  = var.aws_region
  }
}

resource "mcma_service" "service" {
  depends_on = [
    aws_apigatewayv2_api.service_api,
    aws_apigatewayv2_integration.service_api,
    aws_apigatewayv2_route.service_api_default,
    aws_apigatewayv2_route.service_api_options,
    aws_apigatewayv2_stage.service_api,
    aws_dynamodb_table.service_table,
    aws_iam_role.api_handler,
    aws_iam_role_policy.api_handler,
    aws_lambda_function.api_handler,
    aws_lambda_permission.service_api_default,
    aws_lambda_permission.service_api_options,
  ]

  name      = var.name
  auth_type = local.service_auth_type

  resource {
    resource_type = "Service"
    http_endpoint = "${local.service_url}/services"
  }

  resource {
    resource_type = "JobProfile"
    http_endpoint = "${local.service_url}/job-profiles"
  }
}
