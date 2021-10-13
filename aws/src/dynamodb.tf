######################
# DynamoDB
######################

resource "aws_dynamodb_table" "service_table" {
  name         = var.prefix
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "resource_pkey"
  range_key    = "resource_skey"

  attribute {
    name = "resource_pkey"
    type = "S"
  }

  attribute {
    name = "resource_skey"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = var.tags
}

#######################
# DynamoDB Resources
#######################

resource "random_uuid" "service_registry" {
}

resource "aws_dynamodb_table_item" "service_registry" {
  table_name = aws_dynamodb_table.service_table.name
  hash_key   = aws_dynamodb_table.service_table.hash_key
  range_key  = aws_dynamodb_table.service_table.range_key

  item = jsonencode({
    resource_pkey : {
      S : "/services"
    }
    resource_skey : {
      S : random_uuid.service_registry.result
    }

    resource : {
      M : {
        "@type" : {
          S : "Service"
        }
        id : {
          S : "${local.service_url}/services/${random_uuid.service_registry.result}"
        }
        name : {
          S : var.name
        }
        authType : {
          S : "AWS4"
        }
        resources : {
          L : [
            {
              M : {
                "@type" : {
                  S : "ResourceEndpoint"
                }
                resourceType : {
                  S : "Service"
                }
                httpEndpoint : {
                  S : "${local.service_url}/services"
                }
              }
            },
            {
              M : {
                "@type" : {
                  S : "ResourceEndpoint"
                }
                resourceType : {
                  S : "JobProfile"
                }
                httpEndpoint : {
                  S : "${local.service_url}/job-profiles"
                }
              }
            },
          ]
        }
      }
    }
  })
}

resource "random_uuid" "job_profiles" {
  for_each = {for jp in local.job_profiles : jp.name => jp}
}

resource "aws_dynamodb_table_item" "job_profiles" {
  for_each = {for jp in local.job_profiles : jp.name => jp}

  table_name = aws_dynamodb_table.service_table.name
  hash_key   = aws_dynamodb_table.service_table.hash_key
  range_key  = aws_dynamodb_table.service_table.range_key

  item = jsonencode({
    resource_pkey : {
      S : "/job-profiles"
    }
    resource_skey : {
      S : random_uuid.job_profiles[each.key].result
    }
    resource : {
      M : {
      for k, v in {
        "@type" : {
          S : "JobProfile"
        }
        id : {
          S : "${local.service_url}/job-profiles/${random_uuid.job_profiles[each.key].result}"
        }
        name : {
          S : each.key
        }
        inputParameters : {
          L : [
          for p in coalesce(each.value.input_parameters, []) : {
            M : {
              "@type" : {
                S : "JobParameter"
              }
              parameterName : {
                S : p.parameter_name
              }
              parameterType : {
                S : p.parameter_type
              }
            }
          }
          ]
        }
        optionalInputParameters : {
          L : [
          for p in coalesce(each.value.optional_input_parameters, []) : {
            M : {
              "@type" : {
                S : "JobParameter"
              }
              parameterName : {
                S : p.parameter_name
              }
              parameterType : {
                S : p.parameter_type
              }
            }
          }
          ]
        }
        outputParameters : {
          L : [
          for p in coalesce(each.value.output_parameters, []) : {
            M : {
              "@type" : {
                S : "JobParameter"
              }
              parameterName : {
                S : p.parameter_name
              }
              parameterType : {
                S : p.parameter_type
              }
            }
          }
          ]
        }
      } : k => v if !(
      k == "inputParameters" && length(each.value.input_parameters) == 0 ||
      k == "optionalInputParameters" && length(each.value.optional_input_parameters) == 0 ||
      k == "outputParameters" && length(each.value.output_parameters) == 0)
      }
    }
  })
}

resource "random_uuid" "services" {
  for_each = {for s in var.services : s.name => s}
}

resource "aws_dynamodb_table_item" "services" {
  for_each = {for s in var.services : s.name => s}

  table_name = aws_dynamodb_table.service_table.name
  hash_key   = aws_dynamodb_table.service_table.hash_key
  range_key  = aws_dynamodb_table.service_table.range_key

  item = jsonencode({
    resource_pkey : {
      S : "/services"
    }
    resource_skey : {
      S : random_uuid.services[each.key].result
    }
    resource : {
      M : {
      for k, v in {
        "@type" : {
          S : "Service"
        }
        id : {
          S : "${local.service_url}/services/${random_uuid.services[each.key].result}"
        }
        name : {
          S : each.key
        }
        authType : {
          S : each.value.auth_type
        }
        resources : {
          L : [
          for r in each.value.resources : {
            M : {
            for k, v in {
              "@type" : {
                S : "ResourceEndpoint"
              }
              resourceType : {
                S : r.resource_type
              }
              httpEndpoint : {
                S : r.http_endpoint
              }
              authType : {
                S : r.auth_type
              }
            } : k => v if !(k == "authType" && r.auth_type == null)
            }
          }
          ]
        }
        jobType : {
          S : each.value.job_type
        }
        jobProfileIds : {
          L : [
          for jp in coalesce(each.value.job_profiles, []) : {
            S : "${local.service_url}/job-profiles/${random_uuid.job_profiles[jp.name].result}"
          }
          ]
        }
      } : k => v if !(
      k == "authType" && each.value.auth_type == null ||
      k == "jobType" && each.value.job_type == null ||
      k == "jobProfileIds" && length(each.value.job_profiles) == 0
      )
      }
    }
  })
}

locals {
  job_profiles = flatten([for service in var.services : [for jp in coalesce(service.job_profiles, []) : jp]])
}
