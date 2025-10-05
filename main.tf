terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region to deploy the PetStore API"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

locals {
  environment = "demo"
  lambda_name = "PetStoreHandler"
  table_name  = "PetsTable"
}

# --- DynamoDB Table ---
resource "aws_dynamodb_table" "pets" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = local.environment
  }
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.lambda_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Environment = local.environment
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# --- Inline policy for DynamoDB + Logs ---
resource "aws_iam_role_policy" "lambda_policy" {
  name = "PetStoreLambdaDynamoDBAccess"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowDynamoDBAccessForPetsTable"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Scan", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.pets.arn
      },
      {
        Sid    = "AllowLambdaLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# --- Lambda Function ---
resource "aws_lambda_function" "petstore" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")

  tags = {
    Environment = local.environment
  }
}

# --- Lambda Permission for API Gateway ---
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.petstore.function_name
  principal     = "apigateway.amazonaws.com"
}

# --- API Gateway from Swagger ---
resource "aws_api_gateway_rest_api" "petstore_api" {
  name        = "PetStore"
  description = "Full CRUD PetStore API powered by Lambda + DynamoDB"
  #   body        = file("${path.module}/petstore-lambda-crud.json")
  body = templatefile("${path.module}/petstore-lambda-crud.json", {
    account_id = data.aws_caller_identity.current.account_id
  })


  tags = {
    Environment = local.environment
  }
}

# # --- Deployment ---
# resource "aws_api_gateway_deployment" "petstore_deploy" {
#   depends_on  = [aws_api_gateway_rest_api.petstore_api]
#   rest_api_id = aws_api_gateway_rest_api.petstore_api.id
#   stage_name  = "dev"
# }

# # --- Output Section: All Endpoints ---
# output "petstore_api_endpoints" {
#   description = "Base URL and CRUD endpoints for the PetStore API"
#   value = {
#     base_url   = aws_api_gateway_deployment.petstore_deploy.invoke_url
#     list_pets  = "${aws_api_gateway_deployment.petstore_deploy.invoke_url}pets"
#     create_pet = "${aws_api_gateway_deployment.petstore_deploy.invoke_url}pets"
#     get_pet    = "${aws_api_gateway_deployment.petstore_deploy.invoke_url}pets/{petId}"
#     update_pet = "${aws_api_gateway_deployment.petstore_deploy.invoke_url}pets/{petId}"
#     delete_pet = "${aws_api_gateway_deployment.petstore_deploy.invoke_url}pets/{petId}"
#   }
# }

# --- Deployment ---
resource "aws_api_gateway_deployment" "petstore_deploy" {
  depends_on  = [aws_api_gateway_rest_api.petstore_api]
  rest_api_id = aws_api_gateway_rest_api.petstore_api.id
  description = "PetStore API deployment"
}

# --- Stage (replaces deprecated stage_name) ---
resource "aws_api_gateway_stage" "petstore_stage" {
  rest_api_id   = aws_api_gateway_rest_api.petstore_api.id
  deployment_id = aws_api_gateway_deployment.petstore_deploy.id
  stage_name    = "dev"

  tags = {
    Environment = local.environment
  }
}

# --- Outputs (modern, no deprecated attributes) ---
output "petstore_api_endpoints" {
  description = "Base URL and CRUD endpoints for the PetStore API"
  value = {
    base_url   = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/"
    list_pets  = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/pets"
    create_pet = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/pets"
    get_pet    = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/pets/{petId}"
    update_pet = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/pets/{petId}"
    delete_pet = "https://${aws_api_gateway_rest_api.petstore_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.petstore_stage.stage_name}/pets/{petId}"
  }
}

##################################################
# API Gateway → CloudWatch logging configuration #
##################################################

# 1️⃣ IAM role that API Gateway will assume to push logs to CloudWatch
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "APIGatewayCloudWatchLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "apigateway.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# 2️⃣ Attach AWS managed policy with the required permissions
resource "aws_iam_role_policy_attachment" "apigw_logs_policy" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# 3️⃣ Tell API Gateway to use this role
resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

# 4️⃣ Enable execution logging and metrics at the stage level
resource "aws_api_gateway_method_settings" "logging" {
  rest_api_id = aws_api_gateway_rest_api.petstore_api.id
  stage_name  = aws_api_gateway_stage.petstore_stage.stage_name

  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"     # Options: OFF | ERROR | INFO
    data_trace_enabled = true    # Log full request/response data
  }

  depends_on = [aws_api_gateway_account.account]
}

