provider "aws" {
    region     = "eu-west-3"
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
  }

  variable "aws_access_key" {
    description = "AWS access key"
    type        = string
  }

  variable "aws_secret_key" {
    description = "AWS secret key"
    type        = string
  }

  resource "aws_iam_role" "lambda_role" {
    name = "g10-lambda_role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role       = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  }

  resource "aws_lambda_function" "lambda_function" {
    function_name = "g10-lambda"
    role          = aws_iam_role.lambda_role.arn
    handler       = "index.handler"
    runtime       = "nodejs22.x"
    filename      = "lambda.zip"
    source_code_hash = filebase64sha256("lambda.zip")

    environment {
      variables = {
        NODE_ENV = "production"
      }
    }
  }

  resource "aws_s3_bucket" "lambda_bucket" {
    bucket = "g10-lambda-bucket"
  }

  resource "aws_s3_object" "uploaded_file" {
    bucket = aws_s3_bucket.lambda_bucket.id
    key    = "lambda.zip"
    source = "lambda.zip"
    etag   = filemd5("lambda.zip")
  }

  resource "aws_api_gateway_rest_api" "api" {
    name        = "g10-api"
    description = "API Gateway for g10 Lambda function"
  }

  resource "aws_api_gateway_resource" "resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id   = aws_api_gateway_rest_api.api.root_resource_id
    path_part   = "g10"
  }

  resource "aws_api_gateway_method" "method" {
    rest_api_id   = aws_api_gateway_rest_api.api.id
    resource_id   = aws_api_gateway_resource.resource.id
    http_method   = "GET"
    authorization = "NONE"
  }

  resource "aws_api_gateway_integration" "integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.resource.id
    http_method = aws_api_gateway_method.method.http_method
    type        = "AWS_PROXY"
    integration_http_method = "POST"
    uri         = aws_lambda_function.lambda_function.invoke_arn
  }

  resource "aws_lambda_permission" "api_gateway" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda_function.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
  }

  resource "aws_api_gateway_deployment" "deployment" {
    depends_on = [aws_api_gateway_integration.integration]
    rest_api_id = aws_api_gateway_rest_api.api.id
  }

  output "lambda_function_arn" {
    value = aws_lambda_function.lambda_function.arn
  }

  output "api_url" {
    value = "${aws_api_gateway_deployment.deployment.invoke_url}/g10"
  }