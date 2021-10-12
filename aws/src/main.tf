##################################
# aws_iam_role + aws_iam_policy
##################################

locals {
  name_api_handler = format("%.64s", replace("${var.prefix}-api-handler", "/[^a-zA-Z0-9_]+/", "-" ))
}

resource "aws_iam_role" "api_handler" {
  name               = local.name_api_handler
  path               = var.iam_role_path
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaAssumingRole"
        Effect    = "Allow"
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "api_handler" {
  name   = aws_iam_role.api_handler.name
  role   = aws_iam_role.api_handler.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = concat([
      {
        Sid      = "DescribeCloudWatchLogs"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      },
      {
        Sid      = "WriteToCloudWatchLogs"
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = concat([
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:${var.log_group.name}:*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${local.name_api_handler}:*",
        ], var.enhanced_monitoring_enabled ? [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda-insights:*"
        ] : [])
      },
      {
        Sid      = "ListAndDescribeDynamoDBTables",
        Effect   = "Allow",
        Action   = [
          "dynamodb:List*",
          "dynamodb:DescribeReservedCapacity*",
          "dynamodb:DescribeLimits",
          "dynamodb:DescribeTimeToLive"
        ],
        Resource = "*"
      },
      {
        Sid      = "SpecificTable",
        Effect   = "Allow",
        Action   = [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:CreateTable",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.service_table.arn
      }
    ],
    var.xray_tracing_enabled ?
    [
      {
        Sid      = "AllowLambdaWritingToXRay"
        Effect   = "Allow",
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
        ],
        Resource = "*"
      }
    ] : [])
  })
}

######################
# aws_dynamodb_table
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

#################################
#  aws_lambda_function : api_handler
#################################

resource "aws_lambda_function" "api_handler" {
  depends_on = [
    aws_iam_role_policy.api_handler
  ]

  filename         = "${path.module}/lambdas/api-handler.zip"
  function_name    = local.name_api_handler
  role             = aws_iam_role.api_handler.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambdas/api-handler.zip")
  runtime          = "nodejs14.x"
  timeout          = "30"
  memory_size      = "3008"

  layers = var.enhanced_monitoring_enabled ? ["arn:aws:lambda:${var.aws_region}:580247275435:layer:LambdaInsightsExtension:14"] : []

  environment {
    variables = {
      LogGroupName = var.log_group.name
      TableName    = aws_dynamodb_table.service_table.name
      PublicUrl    = local.service_url
    }
  }

  tracing_config {
    mode = var.xray_tracing_enabled ? "Active" : "PassThrough"
  }

  tags = var.tags
}

##############################
#  aws_apigatewayv2_api:  service_api
##############################

resource "aws_apigatewayv2_api" "service_api" {
  name          = var.prefix
  description   = "Service Registry Rest Api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "service_api" {
  api_id                 = aws_apigatewayv2_api.service_api.id
  connection_type        = "INTERNET"
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_handler.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "service_api_options" {
  api_id             = aws_apigatewayv2_api.service_api.id
  route_key          = "OPTIONS /{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.service_api.id}"
}

resource "aws_lambda_permission" "service_api_options" {
  statement_id  = "AllowExecutionFromAPIGatewayOptions"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.service_api.execution_arn}/*/*/{proxy+}"
}

resource "aws_apigatewayv2_route" "service_api_default" {
  api_id             = aws_apigatewayv2_api.service_api.id
  route_key          = "$default"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.service_api.id}"
}

resource "aws_lambda_permission" "service_api_default" {
  statement_id  = "AllowExecutionFromAPIGatewayDefault"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.service_api.execution_arn}/*/$default"
}

resource "aws_apigatewayv2_stage" "service_api" {
  depends_on = [
    aws_apigatewayv2_route.service_api_options,
    aws_apigatewayv2_route.service_api_default
  ]

  api_id      = aws_apigatewayv2_api.service_api.id
  name        = var.stage_name
  auto_deploy = true

  default_route_settings {
    data_trace_enabled       = var.xray_tracing_enabled
    detailed_metrics_enabled = var.api_gateway_metrics_enabled
    logging_level            = var.api_gateway_logging_enabled ? "INFO" : null
    throttling_burst_limit   = 5000
    throttling_rate_limit    = 10000
  }

  access_log_settings {
    destination_arn = var.log_group.arn
    format          = "{ \"requestId\":\"$context.requestId\",\"ip\": \"$context.identity.sourceIp\",\"requestTime\":\"$context.requestTime\",\"httpMethod\":\"$context.httpMethod\",\"routeKey\":\"$context.routeKey\",\"path\":\"$context.path\",\"status\":\"$context.status\",\"protocol\":\"$context.protocol\",\"responseLength\":\"$context.responseLength\",\"responseLength\":\"$context.responseLength\" }"
  }

  tags = var.tags
}

locals {
  service_url       = "${aws_apigatewayv2_api.service_api.api_endpoint}/${var.stage_name}"
  service_auth_type = "AWS4"
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
