# TODO eventually remove this provider
provider "mcma" {
  service_registry_url = aws_apigatewayv2_stage.service_api.invoke_url

  aws4_auth {
    profile = var.aws_profile
    region  = var.aws_region
  }
}
