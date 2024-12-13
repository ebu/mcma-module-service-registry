# output "service_registry_aws" {
#   value = {
#     auth_type   = module.service_registry_aws.auth_type
#     service_url = module.service_registry_aws.service_url
#   }
# }
#
# output "service_registry_azure" {
#   value = {
#     auth_type   = module.service_registry_azure.auth_type
#     service_url = module.service_registry_azure.service_url
#   }
# }
#
# output "deployment_api_key" {
#   sensitive = true
#   value     = random_password.deployment_api_key.result
# }

output "module_azure" {
  sensitive = true
  value     = module.service_registry_azure
}
