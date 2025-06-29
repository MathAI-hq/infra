############################################
# Lambda + HTTP API “Sign-Up” module
#  - Creates an IAM role with least-privilege
#  - Packages code in ./zip into a ZIP file
#  - Deploys the Lambda
#  - Exposes POST /signup via HTTP API Gateway
#  - Outputs the public endpoint
############################################

############################################
# 1. IAM role and policy
############################################
resource "aws_iam_role" "lambda_role" {
  name               = "${var.lambda_name}_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "AllowLambdaBasicAndDynamoDB"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


############################################
# 2. Package Lambda code in ./zip as ZIP
############################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/zip"
  output_path = "${path.module}/lambda.zip"
}

############################################
# 3. Lambda function
############################################
resource "aws_lambda_function" "signup_handler" {
  function_name    = var.lambda_name
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "handler.handler"

  # ⬇️ NEW
  timeout          = 15          # seconds
  memory_size      = 256         # MB  (helps bcrypt & cold start)

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table
    }
  }
}
############################################
# 4. HTTP API Gateway
############################################
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.lambda_name}_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                = aws_apigatewayv2_api.http_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.signup_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "signup_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# -------------------------------------------------
# 4-A. HTTP API Stage ($default, auto-deploy)
# -------------------------------------------------
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"        # special name: $default
  auto_deploy = true
}

############################################
# 5. Allow API Gateway to invoke the Lambda
############################################
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "APIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

############################################
# 6. Outputs
############################################
output "signup_api_url" {
  description = "Public URL for POST /signup"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/signup"
}

