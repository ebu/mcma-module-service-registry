output "auth_type" {
  value = local.service_auth_type
}

output "services_url" {
  value = "${local.service_url}/services"
}

output "job_profiles_url" {
  value = "${local.service_url}/job-profiles"
}

# exporting all resources from module
output "aws_iam_role" {
  value = {
    lambda_execution = aws_iam_role.api_handler
  }
}

output "aws_iam_role_policy" {
  value = {
    lambda_execution = aws_iam_role_policy.api_handler
  }
}

output "aws_dynamodb_table" {
  value = {
    service_table = aws_dynamodb_table.service_table
  }
}

output "aws_lambda_function" {
  value = {
    api_handler = aws_lambda_function.api_handler
  }
}

output "aws_apigatewayv2_api" {
  value = {
    service_api = aws_apigatewayv2_api.service_api
  }
}

output "aws_apigatewayv2_integration" {
  value = {
    service_api = aws_apigatewayv2_integration.service_api
  }
}

output "aws_apigatewayv2_route" {
  value = {
    service_api_default = aws_apigatewayv2_route.service_api_default
    service_api_options = aws_apigatewayv2_route.service_api_options
  }
}

output "aws_lambda_permission" {
  value = {
    service_api_default = aws_lambda_permission.service_api_default
    service_api_options = aws_lambda_permission.service_api_options
  }
}

output "aws_apigatewayv2_stage" {
  value = {
    service_api = aws_apigatewayv2_stage.service_api
  }
}
