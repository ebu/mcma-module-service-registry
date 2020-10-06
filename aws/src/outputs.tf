output "auth_type" {
  value = local.service_auth_type
}

output "services_url" {
  value = "${local.service_url}/services"
}

output "job_profiles_url" {
  value = "${local.service_url}/job-profiles"
}

output "apigateway_execution_arn" {
  value = aws_apigatewayv2_stage.service_api.execution_arn
}
