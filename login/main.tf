############################################
# Login Lambda + /login HTTP API Route
############################################

########################
# IAM Role + Policy
########################
resource "aws_iam_role" "lambda_role" {
  name               = "${var.lambda_name}_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# allow Query + UpdateItem + CloudWatch logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "AllowQueryUpdateLogs"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:Query", "dynamodb:UpdateItem"],
        Resource = [
          var.dynamodb_table_arn,                 # table itself
          "${var.dynamodb_table_arn}/index/*"     # all GSIs on that table
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


########################
# Package Lambda code
########################
data "archive_file" "zip" {
  type        = "zip"
  source_dir  = "${path.module}/zip"
  output_path = "${path.module}/login_lambda.zip"
}

resource "aws_lambda_function" "login_handler" {
  function_name    = var.lambda_name
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "handler.handler"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  timeout      = 15   # seconds
  memory_size  = 256  # MB

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table
    }
  }
}

########################
# API Gateway Integration & Route
########################
resource "aws_apigatewayv2_integration" "login_integration" {
  api_id                = var.http_api_id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.login_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "login_route" {
  api_id    = var.http_api_id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.login_integration.id}"
}

########################
# Allow API Gateway to invoke Lambda
########################
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "APIGatewayInvokeLogin"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.http_api_execution_arn}/*/*"
}

########################
# (Optional) output
########################
output "login_api_url" {
  value = "${var.base_invoke_url}/login"
  description = "POST /login endpoint"
}


