##################################
# aws_iam_role + aws_iam_policy
##################################

resource "aws_iam_role" "lambda_execution" {
  name               = format("%.64s", "${var.module_prefix}.${var.aws_region}.lambda-execution")
  path               = var.iam_role_path
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaAssumingRole"
        Effect    = "Allow"
        Action    = "sts:AssumeRole",
        Principal = {
          "Service" = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "lambda_execution" {
  name        = format("%.128s", "${var.module_prefix}.${var.aws_region}.lambda-execution")
  description = "Policy to write to log"
  path        = var.iam_policy_path
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowLambdaWritingToLogs"
        Effect   = "Allow",
        Action   = "logs:*",
        Resource = "*"
      },
      {
        Sid      = "AllowLambdaWritingToXRay"
        Effect   = "Allow",
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
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
        Resource = "arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.service_table.name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.id
  policy_arn = aws_iam_policy.lambda_execution.arn
}

######################
# aws_dynamodb_table
######################

resource "aws_dynamodb_table" "service_table" {
  name         = var.module_prefix
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "partition_key"
  range_key    = "sort_key"

  attribute {
    name = "partition_key"
    type = "S"
  }

  attribute {
    name = "sort_key"
    type = "S"
  }

  tags = var.tags
}

#################################
#  aws_lambda_function : api-handler
#################################

resource "aws_lambda_function" "api_handler" {
  filename         = "${path.module}/lambdas/api-handler.zip"
  function_name    = format("%.64s", replace("${var.module_prefix}-api-handler", "/[^a-zA-Z0-9_]+/", "-" ))
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambdas/api-handler.zip")
  runtime          = "nodejs12.x"
  timeout          = "30"
  memory_size      = "3008"

  environment {
    variables = {
      LogGroupName = var.log_group_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
}

##############################
#  aws_api_gateway_rest_api:  service_api
##############################
resource "aws_api_gateway_rest_api" "service_api" {
  name        = var.module_prefix
  description = "Service Registry Rest Api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "service_api" {
  rest_api_id = aws_api_gateway_rest_api.service_api.id
  parent_id   = aws_api_gateway_rest_api.service_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "service_api_options" {
  rest_api_id   = aws_api_gateway_rest_api.service_api.id
  resource_id   = aws_api_gateway_resource.service_api.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "service_api_options" {
  rest_api_id = aws_api_gateway_rest_api.service_api.id
  resource_id = aws_api_gateway_resource.service_api.id
  http_method = aws_api_gateway_method.service_api_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "service_api_options" {
  rest_api_id = aws_api_gateway_rest_api.service_api.id
  resource_id = aws_api_gateway_resource.service_api.id
  http_method = aws_api_gateway_method.service_api_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_integration_response" "service_api_options" {
  rest_api_id = aws_api_gateway_rest_api.service_api.id
  resource_id = aws_api_gateway_resource.service_api.id
  http_method = aws_api_gateway_method.service_api_options.http_method
  status_code = aws_api_gateway_method_response.service_api_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,PATCH,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "service_api_handler" {
  rest_api_id   = aws_api_gateway_rest_api.service_api.id
  resource_id   = aws_api_gateway_resource.service_api.id
  http_method   = "ANY"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "service_api_handler" {
  rest_api_id             = aws_api_gateway_rest_api.service_api.id
  resource_id             = aws_api_gateway_resource.service_api.id
  http_method             = aws_api_gateway_method.service_api_handler.http_method
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${aws_lambda_function.api_handler.function_name}/invocations"
  integration_http_method = "POST"
}

resource "aws_lambda_permission" "service_api_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${aws_api_gateway_rest_api.service_api.id}/*/${aws_api_gateway_method.service_api_handler.http_method}/*"
}

resource "aws_api_gateway_deployment" "service_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.service_api_options,
    aws_api_gateway_integration.service_api_handler,
  ]

  rest_api_id = aws_api_gateway_rest_api.service_api.id
}

resource "aws_api_gateway_stage" "service_registry_gateway_stage" {
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.service_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.service_api.id

  variables = {
    "TableName" = aws_dynamodb_table.service_table.name
    "PublicUrl" = local.service_url
  }

  tags = var.tags
}


locals {
  service_url       = "https://${aws_api_gateway_rest_api.service_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}"
  service_auth_type = "AWS4"
}
